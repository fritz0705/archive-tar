class Archive::Tar::Writer
  def initialize(file, options = {})
    options = {
      :block_size => 2 ** 19
    }.merge(options)

    @block_size = options[:block_size]
    @file = file
  end

  def add(header, content)
    @file.write(Archive::Tar::Format::pack_header(header))
    
    content = content[0, header[:size]]
    real_size = Archive::Tar::Format::blocks_for_bytes(header[:size]) * 512
    @file.write(content.ljust(real_size, "\0"))
  end
end