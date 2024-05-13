def transform(map)
  map
    .sort_by { |topic, _| topic.rpartition(".@")[2] }.to_h
    .transform_keys { |topic| topic.rpartition(".@")[0] }
end

module DirReader
  def self.read(path)
    output = Dir.each_child(path).map do |topic|
      contents = Dir.each_child(File.join(path, topic)).map do |subtopic|
        contents = Dir.each_child(File.join(path, topic, subtopic)).map do |post|
          post
        end
        [subtopic, transform(contents)]
      end.to_h
      [topic, transform(contents)]
    end.to_h

    transform(output)
  end
end