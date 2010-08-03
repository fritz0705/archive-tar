class Archive::Tar::Writer
  def initialize(file, options = {})
    options = {
      :block_size => 2 ** 19
    }.merge(options)

    @block_size = options[:block_size]
    @file = file
  end

  def add_header(header, content)
    @file.write(Archive::Tar::Format::pack_header(header))
    
    content = content[0, header[:size]]
    real_size = Archive::Tar::Format::blocks_for_bytes(header[:size]) * 512
    @file.write(content.ljust(real_size, "\0"))
  end
  
  def add_file(file, path = nil)
    header_hash = Archive::Tar::Format::header_for_file(file, path)
    header = Archive::Tar::Format::pack_header(header_hash)
    @file.write(header)
    file.rewind
    
    if header_hash[:type] == :normal
      num_of_nils = header_hash[:blocks] * 512 - header_hash[:size]
      until file.eof?
        @file.write(file.read(@block_size))
      end
      
      @file.write("\0" * num_of_nils)
    end
  end
end
