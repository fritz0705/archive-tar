require "archive/tar/reader"

class Archive::Tar::StreamReader < Archive::Tar::Reader
  def initialize(stream, options = {})
    options = {
      block_size: 2 ** 19,
      reload_time: 32
    }.merge(options)
  
    if options[:compression] == :auto
      raise "Automatic compression is not available for streams"
    end
    
    tmp_file = File.new("/tmp/" + rand(500000).to_s(16) + ".tar", "w+b")
    Thread.new do
      i = 0
    
      puts "Copy to tmp file..."
      until stream.eof?
        read = stream.read(options[:block_size])
        tmp_file.write(read)
        self.build_index if i % options[:reload_time] == 0
        puts "Rebuild" if i % options[:reload_time] == 0
        i += 1
      end
      puts "Done!"
      
      self.build_index
    end
    
    super(tmp_file, options)
  end
end
