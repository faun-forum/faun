require "async"
require "async/io"
require "async/io/generic"
require "async/io/protocol/line"
require "yaml"

class Section < Hash
  def initialize(path, type)
    super()
    Dir.each_child(path) do |topic|
      dir = File.join(path, topic)
      next unless File.directory?(dir)

      self[topic] = type.new(dir)
    end

    replace(
      sort_by { |topic, _| topic.rpartition(".@")[2] }
        .to_h
        .transform_keys { |topic| topic.rpartition(".@")[0] }
    )
  end
end

class Forum < Section
  def initialize(path)
    super(path, Topic)
  end
end

class Topic < Section
  def initialize(path)
    super(path, Subtopic)
  end
end

class Subtopic < Section
  def initialize(path)
    super(path, Post)
  end
end

class Threads < Section
  def initialize(path)
    super(path, ForumThread)
  end
end

class Post
  attr_reader :meta, :content, :threads

  def initialize(path)
    @threads = Threads.new(path)
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

  def to_json(*args)
    json = @meta
    json.merge!(
      'content' => @content,
      'threads' => @threads
    )
    json.to_json(*args)
  end
end

class ForumThread < Section
  def initialize(path)
    super(path, Comment)
  end
end

class Comment
  def initialize(_)
  end
end
