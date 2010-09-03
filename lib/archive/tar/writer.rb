require "archive/tar/stat.rb"
require "archive/tar/format.rb"

class Archive::Tar::Writer
  def initialize(file, options = {})
    options = {
      :block_size => 2 ** 19,
      :format => :gnu
    }.merge(options)

    @block_size = options[:block_size]
    @file = file
    @format = options[:format]
  end
  
  def add_entry(header, content)
    @file.write(Archive::Tar::Format::pack_header(header))
    
    content = content[0, header[:size]]
    real_size = Archive::Tar::Format::blocks_for_bytes(header[:size]) * 512
    @file.write(content.ljust(real_size, "\0"))
  end
  
  def add_file(file, path = nil)
    unless file.is_a? File
      file = File.new(file)
    end
  
    stat = Archive::Tar::Stat::from_file(file)
    stat.path = path
    stat.format = @format
    header = Archive::Tar::Format::pack_header(stat)
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
  
  def add_directory(dir, full_path = false, recursive = false)
    dir_base = dir.path + "/"
    archive_base = full_path ? dir_base : ""
    
    unless dir.is_a? Dir
      dir = Dir.open(dir)
    end
    
    dir.each do |i|
      if i == "." || i == ".."
        next
      end
    
      realpath = dir_base + i
      real_archive_path = archive_base + i
      
      add_file(realpath, real_archive_path)
      
      add_directory(realpath, full_path) if File::Stat.new(realpath).directory? && recursive
    end
  end
end
