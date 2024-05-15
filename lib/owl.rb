require "async"
require "async/io"
require "async/io/generic"
require "async/io/protocol/line"
require "yaml"

require_relative "owl/version"

module Owl
  class Error < StandardError; end

  class Section
    attr_reader :id, :items

    def initialize(id, path, type)
      @id = id

      subs = {}
      Dir.each_child(path) do |section|
        dir = File.join(path, section)
        next unless File.directory?(dir) and not section.start_with?('.')

        name, _, id = section.rpartition(".@")
        subs[name] = type.new(id.to_i, dir)
      end
      @items = subs.sort_by { |_, sub| sub.id }.to_h
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

    def initialize(id, path, type)
      super(id, path, type)

      Async do
        begin
          File.open(File.join(path, "meta.yaml"), "r") do |file|
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
    def initialize(path)
      super(0, path, Topic)
    end

    def item_name
      "topics"
    end
  end

  class Topic < SectionWithMeta
    def initialize(id, path)
      super(id, path, Subtopic)
    end

    def item_name
      "chapters"
    end
  end

  class Subtopic < SectionWithMeta
    def initialize(id, path)
      super(id, path, Post)
    end

    def item_name
      "posts"
    end
  end

  class Post < Section
    attr_reader :id, :meta, :content

    def initialize(id, path)
      super(id, path, ForumThread)
      Async do
        File.open(File.join(path, "latest.md"), "r") do |file|
          generic = Async::IO::Stream.new(file)
          lines = Async::IO::Protocol::Line.new(generic).each_line
          lines.next
          meta = lines.take_while { |line| line.strip != "---" }.join("\n")
          # lines.next while lines.peek.strip.empty?
          @meta = YAML.load(meta)
          @content = generic.read
        end
      end
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
    def initialize(id, path)
      super(id, path, NilClass)
    end

    def item_name
      "comments"
    end
  end

  class Comment
  end
end
