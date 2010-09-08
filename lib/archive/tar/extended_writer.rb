require "archive/tar/writer"
require "archive/tar/reader"

class Archive::Tar::ExtendedWriter < Archive::Tar::Writer
  def remove_file(name)
    reader = Archive::Tar::Reader.new(@stream)
    
    header, offset = reader[name]
    remove_blocks(offset / 512, header.blocks)
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

