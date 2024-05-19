# frozen_string_literal: true

require "async"
require "async/io"
require "async/io/generic"
require "async/io/protocol/line"
require "yaml"

require_relative "faun/version"

module Faun
  class Error < StandardError; end

  class Section
    attr_reader :id, :name, :items, :parent

    def initialize(id, name, path, parent)
      @id = id
      @parent = parent
      @name = name
      @path = path

      subs = {}
      Dir.each_child(path) do |section|
        dir = File.join(path, section)
        next unless File.directory?(dir) and not section.start_with?('.')

        name, _, subid = section.rpartition(".@")
        subid = subid.to_i
        unless parent.nil?
          parent = parent.clone
          parent[my_symbol] = @id if respond_to?(:my_symbol)
        end
        subs[subid] = items_type.new(subid, name, dir, parent)
      end
      @items = subs.sort_by { |subid, _| subid }.to_h
    end

    def each(&block); @items.each(&block); end
    def each_key(&block); @items.each_key(&block); end
    def each_value(&block); @items.each_value(&block); end

    def as_json(short:)
      j = {
        :id => @id,
        :name => @name,
      }
      j[:parent] = @parent if @parent
      j[items_symbol] = @items unless json_skips_items
      j
    end

    def to_json(*args, short: false)
      as_json(short:).to_json(*args)
    end

    def json_skips_items; false; end
    def items_symbol; :items; end
  end

  class SectionWithMeta < Section
    attr_reader :meta

    def initialize(id, name, path, parent = nil)
      super(id, name, path, parent)

      Async do
        begin
          File.open(File.join(path, "meta.yaml"), "r:UTF-8") do |file|
            generic = Async::IO::Stream.new(file)
            @meta = YAML.load(generic.read)
          end
        rescue
          @meta = {}
        end
      end.wait
    end

    def as_json(short:); @meta.merge(super(short:)); end
  end

  module PostsJson
    def posts_json
      puts posts.keys
      posts.map { |id, post| [id, post.as_json(short: true)] }.to_h.to_json
    end
  end

  class Forum < SectionWithMeta
    include PostsJson

    attr_reader :posts, :seo, :defaults, :users

    def initialize(path)
      Async do
        File.open(File.join(path, "users.yaml"), "r:UTF-8") do |file|
          generic = Async::IO::Stream.new(file)
          @users = YAML.load(generic.read)
        end
      end.wait

      super(0, nil, path)

      @name = @meta["name"]
      @meta.delete("name")

      @posts = @items.flat_map { |_, topic| topic.posts.to_a }.sort_by { |id, _| id }.reverse.to_h
    end

    def seo; @meta["seo"] || {}; end
    def defaults; @meta["defaults"] || {}; end
    def author_name(nick); @meta["authors"][nick] || nick; end

    def topic_from(path)
      id, subid = path.split('.')
      topic = @items[id.to_i]
      topic = topic.subtopic(subid.to_i) if subid
      topic
    end

    def topic(id); @items[id]; end
    def subtopic(id, subid); @items[id].subtopic(subid); end
    def post(id); @posts[id]; end

    def items_type; Topic; end
    def items_symbol; :topics; end
  end

  class Topic < SectionWithMeta
    include PostsJson

    attr_reader :posts

    def initialize(id, name, path, parent)
      raise "Non-nil parent for a topic" unless parent.nil?
      super(id, name, path, {})

      @posts = @items.flat_map { |_, sub|  sub.posts.to_a }.sort_by { |id, _| id }.reverse.to_h
    end

    def subtopic(subid); @items[subid]; end

    def my_symbol; :topic; end
    def items_type; Subtopic; end
    def items_symbol; :subtopics; end
  end

  class Subtopic < SectionWithMeta
    include PostsJson

    alias posts items

    def as_json(short:)
      j = super(short:)
      j[:parent] = j[:parent][:topic]
      j
    end
    def json_skips_items; true; end

    def my_symbol; :subtopic; end
    def items_type; Post; end
    def items_symbol; :posts; end
  end

  class Post < Section
    attr_reader :id, :meta, :content

    def initialize(id, name, path, parent)
      super(id, name, path, parent)

      Async do
        File.open(File.join(path, "latest.md"), "r:UTF-8") do |file|
          generic = Async::IO::Stream.new(file)
          lines = Async::IO::Protocol::Line.new(generic).each_line
          lines.next
          meta = lines.take_while { |line| line.strip != "---" }.join("\n")
          # lines.next while lines.peek.strip.empty?
          @meta = YAML.load(meta)
          @meta["written"] = DateTime.strptime(@meta["written"], "%Y-%m-%d %H:%M")
          @content = generic.read.force_encoding("UTF-8")
        end
      end.wait
    end

    alias title name
    alias threads items

    def author; @meta["author"]; end
    def details; @meta["details"]; end
    def comment_count; @items.values.map { |thread| thread.comments.count }.sum; end
    def comment_authors; @items.values.map{ |thread| thread.authors }.flatten.uniq; end

    def asset_path(name); "#{@path}/.assets/#{name}"; end

    def as_json(short: false)
      j = super(short:)
      j.merge!(@meta)
      if short
        j.merge!(
          thread_count: threads.count,
          comment_count: comment_count,
          comment_authors: comment_authors
        )
        j.delete(:threads)
      else
        j.merge!(content: @content)
      end
      j
    end

    def my_symbol; :post; end
    def items_type; ForumThread; end
    def items_symbol; :threads; end
  end

  class ForumThread < Section
    attr_reader :post

    def initialize(id, name, path, parent)
      @id = id
      @parent = parent
      @name = name
      @path = path

      comments = {}
      Dir.each_child(path) do |filename|
        file = File.join(path, filename)
        next if File.directory?(file) or filename.start_with?('.') or not filename.end_with?('.md')

        id, author, date_string = filename.scan(/^(\d{3})\.(\w+)\.(20\d\d-\d\d-\d\d\.\d\d-\d\d)\.md$/).first
        id = id.to_i
        datetime = DateTime.strptime(date_string, "%Y-%m-%d.%H-%M")

        content = nil
        Async do
          begin
            File.open(file, "r:UTF-8") do |file|
              generic = Async::IO::Stream.new(file)
              content = generic.read.force_encoding("UTF-8")
            end
          rescue
            content = ""
          end
        end.wait

        parent[:thread] = @id
        comments[id] = Comment.new(id, author, datetime, content, parent)
      end
      @items = comments.sort_by { |id, _| id }.to_h
    end

    alias title name
    alias comments items

    def authors
      unique_authors = @items.values.map(&:author).uniq

      if block_given?
        unique_authors.each { |author| yield author }
      else
        unique_authors
      end
    end

    def my_symbol; :thread; end
    def items_type; Comment; end
    def items_symbol; :comments; end
  end

  class Comment
    attr_reader :id, :author, :created, :content, :parent

    def initialize(id, author, created, content, parent)
      @id = id
      @author = author
      @created = created
      @content = content
      @parent = parent
    end

    def markdown_content
      Kramdown::Document.new(@content).to_html
    end

    def as_json(*)
      {
        :id => @id,
        :parent => @parent,
        :author => @author,
        :created => @created,
        :content => @content
      }
    end

    def to_json(*args); as_json(*args).to_json; end
  end
end
