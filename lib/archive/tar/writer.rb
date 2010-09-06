=begin license
Copyright 2010 Fritz Conrad Grimpen. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of
      conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice, this list
      of conditions and the following disclaimer in the documentation and/or other materials
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY FRITZ CONRAD GRIMPEN ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those of the
authors and should not be interpreted as representing official policies, either expressed
or implied, of Fritz Conrad Grimpen.
=end

require "archive/tar/stat.rb"
require "archive/tar/format.rb"

class Archive::Tar::Writer
  include Archive::Tar

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
    
    if stat.type == :normal
      num_of_nils = stat.blocks * 512 - stat.size
      until file.eof?
        @file.write(file.read(@block_size))
      end
      
      @file.write("\0" * num_of_nils)
    end
  end
  
  def add_directory(dir, full_path = false, recursive = false)
    dir_base = normalize_path(dir + "/") + "/"
    archive_base = dir_base
    
    unless dir.is_a? Dir
      dir = Dir.open(dir)
    end
    
    add_file(dir.path, archive_base)
    
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
  
  def close()
    @file.write("\0" * 1024)
  end
end
