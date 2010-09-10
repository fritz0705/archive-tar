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

class Archive::Tar::WriterError < RuntimeError
end

class Archive::Tar::Writer
  include Archive::Tar
  
  def initialize(stream, options = {})
    options = {
      :block_size => 2 ** 19,
      :format => :gnu
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
