=begin license
Copyright (c) 2010 Fritz Grimpen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=end

require "archive/tar/stat.rb"
require "archive/tar/format.rb"

class Archive::Tar::WriterError < RuntimeError
end

class Archive::Tar::Writer
  include Archive::Tar
  
  def initialize(stream, options = {})
    options = {
      block_size: 2 ** 19,
      format: :gnu
    }.merge(options)
    
    @options = options
    @stream = stream
    @inodes = {}
  end
  
  def add_entry(header, content)
    @atream.write(Archive::Tar::Format::pack_header(header))
    
    content = content[0, header.size].ljust(header.blocks * 512, "\0")
    @stream.write(content)
  end
  
  def add_file(file, path = nil)
    file = File.is_a?(File) ? file : File.new(file)
    path = path == nil ? file.path : path
    
    ino = File::Stat.new(file).ino
    stat = Archive::Tar::Stat::from_file(file)
    stat.path = path
    stat.format = @options[:format]
    if @inodes.has_key? ino && path != @inodes[ino]
      stat.type = :link
      stat.size = 0
      stat.dest = @inodes[ino]
    else
      @inodes[ino] = path
    end
    
    header = Archive::Tar::Format::pack_header(stat)
    @stream.write(header)
    
    if stat.type == :normal
      num_of_nils = stat.blocks * 512 - stat.size
      until file.eof?
        @stream.write(file.read(@options[:block_size]))
      end
      
      @stream.write("\0" * num_of_nils)
    end
  end
  
  def add_directory(dir, options = {})
    options = {
      full_path: false,
      recursive: true,
      archive_base: ""
    }.merge(options)
    
    real_base = dir
    archive_base = options[:archive_base]
    
    unless dir.is_a? Dir
      dir = Dir.open(dir)
    end
    
    #add_file(dir.path, archive_base)
    
    dir.each do |entry|
      if entry == "." || entry == ".."
        next
      end
      
      realpath = File.join(real_base, entry)
      real_archive_path = join_path(archive_base, entry)
      
      add_file(realpath, real_archive_path)
      
      if File::Stat.new(realpath).directory? && options[:recursive]
        new_options = options
        new_options[:archive_base] = real_archive_path
        
        add_directory(realpath, new_options)
      end
    end
  end
  
  def close()
    @stream.write("\0" * 1024)
  end
end
