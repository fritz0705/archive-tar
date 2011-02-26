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

class Archive::Tar::Stat
  attr_accessor :checksum, :path, :mode, :uid, :gid, :size, :mtime, :type,
    :dest, :format, :user, :group, :atime, :ctime, :major, :minor
  attr_accessor :path
  attr_accessor :mode
  attr_a

  def initialize
    @path = ""
    @mode = 0777
    @uid = 0
    @gid = 0
    @size = 0
    @mtime = Time.at(0)
    @type = :normal
    @dest = ""
    @format = :ustar
    @user = ""
    @group = ""
    @atime = Time.at(0)
    @ctime = Time.at(0)
    @major = 0
    @minor = 0
    @checksum = 0
  end

  def self.from_file(file)
    file = File.new(file.to_s) unless file.is_a? File
    stat = Archive::Tar::Stat.new
    
    file_stat = file.stat
    path = file.path
    
    stat.path = path
    stat.mode = file_stat.mode
    stat.uid = file_stat.uid
    stat.gid = file_stat.gid
    stat.size = file_stat.size
    stat.mtime = file_stat.mtime
    
    if file_stat.blockdev?
      stat.type = :block
      stat.size = 0
    elsif file_stat.chardev?
      stat.type = :character
      stat.size = 0
    elsif file_stat.directory?
      stat.type = :directory
      stat.size = 0
    elsif file_stat.pipe?
      stat.type = :fifo
      stat.size = 0
    elsif file_stat.symlink?
      stat.type = :symbolic
      stat.size = 0
    else
      stat.type = :normal
    end
    
    stat.dest = File.readlink(path) if stat.type == :symbolic
    stat.format = :ustar
    stat.atime = file_stat.atime
    stat.ctime = file_stat.ctime
    
    stat.major = file_stat.rdev_major
    stat.minor = file_stat.rdev_minor
    
    stat
  end
  
  def blocks
    size % 512 == 0 ? size / 512 : (size + 512 - size % 512) / 512
  end
  
  def is_ustar?
    format == :ustar
  end
  
  def ustar?
    is_ustar?
  end
  
  def is_gnu?
    format == :gnu
  end
  
  def gnu?
    is_gnu?
  end
  
  def version
    "00"
  end
  
  def [](name)
    self.method(name.to_sym).call
  end
  
  def []=(name, value)
    self.method((name.to_s + "=").to_sym).call(value)
  end
  
  def each(&block)
    [ :path, :mode, :uid, :gid, :size, :mtime, :type, :dest, :format, :user,
      :group, :major, :minor, :atime, :ctime, :checksum ].each do |elem|
      block.call(elem, self[elem])
    end
  end
end
