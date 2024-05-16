require "async"
require "async/io"
require "async/io/generic"
require "async/io/protocol/line"
require "yaml"

require_relative "owl/version"

module Owl
  class Error < StandardError; end

  class Section
    attr_reader :id, :name, :items

    def initialize(id, name, path, type)
      @id = id
      @name = name

      subs = {}
      Dir.each_child(path) do |section|
        dir = File.join(path, section)
        next unless File.directory?(dir) and not section.start_with?('.')

        name, _, id = section.rpartition(".@")
        id = id.to_i
        subs[id] = type.new(id, name, dir)
      end
      @items = subs.sort_by { |subid, _| subid }.to_h
    end

    def each(&block)
      @items.each(&block)
    end

    def each_key(&block)
      @items.each_key(&block)
    end

    def each_value(&block)
      @items.each_value(&block)
    end

    def to_json(*args)
      {
        :id => @id,
        item_name => @items
      }.to_json(*args)
    end
  end

  class SectionWithMeta < Section
    attr_reader :meta

    def initialize(id, name, path, type)
      super(id, name, path, type)

      Async do
        begin
          File.open(File.join(path, "meta.yaml"), "r:UTF-8") do |file|
            generic = Async::IO::Stream.new(file)
            @meta = YAML.load(generic.read)
          end
        rescue
          @meta = {}
        end
      end
    end
  end

  class Forum < SectionWithMeta
    attr_reader :posts

    def initialize(path)
      super(0, nil, path, Topic)

      @posts = @items.flat_map do |_, topic|
        topic.posts.to_a
      end.to_h
    end

    def author_name(nick)
      @meta["authors"][nick] || nick
    end

    def subtopic(id, subid)
      @items[id].subtopic(subid)
    end

    def post(id)
      @posts[id]
    end

    def item_name
      "topics"
    end
  end

  class Topic < SectionWithMeta
    attr_reader :posts

    def initialize(id, name, path)
      super(id, name, path, Subtopic)

      @posts = @items.flat_map do |_, sub|
        sub.posts.to_a
      end.to_h
    end

    def subtopic(subid)
      @items[subid]
    end

    def item_name
      "chapters"
    end
  end

  class Subtopic < SectionWithMeta
    def initialize(id, name, path)
      super(id, name, path, Post)
    end

    def posts
      @items
    end

    def item_name
      "posts"
    end
  end

  class Post < Section
    attr_reader :id, :meta, :content

    def initialize(id, name, path)
      super(id, name, path, ForumThread)
      Async do
        File.open(File.join(path, "latest.md"), "r:UTF-8") do |file|
          generic = Async::IO::Stream.new(file)
          lines = Async::IO::Protocol::Line.new(generic).each_line
          lines.next
          meta = lines.take_while { |line| line.strip != "---" }.join("\n")
          # lines.next while lines.peek.strip.empty?
          @meta = YAML.load(meta)
          @content = generic.read.force_encoding("UTF-8")
        end
      end
    end

    def title
      @name
    end

    def author
      @meta["author"]
    end

    def item_name
      "threads"
    end

    def to_json(*args)
      json = @meta.clone
      json.merge!(
        id: @id,
        content: @content,
        threads: @threads
      )
      json.to_json(*args)
    end
  end

  class ForumThread < Section
    def initialize(id, name, path)
      super(id, name, path, NilClass)
    end

    def item_name
      "comments"
    end
  end

  class Comment
  end
end
