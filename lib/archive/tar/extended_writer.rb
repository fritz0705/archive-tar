require "archive/tar/writer"
require "archive/tar/reader"

class Archive::Tar::WriteError < RuntimeError
end

class Archive::Tar::ExtendedWriter < Archive::Tar::Writer
  def load_reader
    Archive::Tar::Reader.new(@stream)
  end

  def remove_file(name)
    reader = load_reader
    header, offset = reader[name]
    remove_blocks(offset / 512, header.blocks)
  end
  
  def rename_file(old_name, new_name)
    reader = load_reader
    
    unless @stream[new_name] == nil
      raise Archive::Tar::WriteError("File `#[new_name}' already exists.")
    end
    
    header, offset = reader[old_name]
    name_offset = offset - 512
    @stream.seek(name_offset)
    @stream.write(new_name.ljust(100, "\0"))
  end
  
  protected
  def remove_blocks(block_offset, num_of_blocks)
    @stream.seek((block_offset + num_of_blocks) * 512, IO::SEEK_SET)
    i = 1
    until @stream.eof?
      new_block = @stream.read(512)
      @stream.seek(block_offset * 512, IO::SEEK_SET)
      @stream.write(new_block)
      @stream.seek((block_offset + num_of_blocks + i) * 512, IO::SEEK_SET)
      i += 1
    end
  end
end

