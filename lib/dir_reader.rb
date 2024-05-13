class Section < Hash
  def initialize(path, type)
    super()
    Dir.each_child(path) { |topic| self[topic] = type.new(File.join(path, topic)) }
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

class Post
  def initialize(_)
  end
end
