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

class Archive::Tar::Stat
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
  
  def checksum
    @checksum
  end
  
  def checksum=(new_checksum)
    @checksum = new_checksum
  end
  
  def path
    @path
  end
  
  def path=(new_path)
    @path = new_path
  end
  
  def mode
    @mode
  end
  
  def mode=(new_mode)
    @mode = new_mode
  end
  
  def uid
    @uid
  end
  
  def uid=(new_uid)
    @uid = new_uid
  end
  
  def gid
    @gid
  end
  
  def gid=(new_gid)
    @gid = new_gid
  end
  
  def size
    @size
  end
  
  def size=(new_size)
    @size = new_size
  end
  
  def blocks
    size % 512 == 0 ? size / 512 : (size + 512 - size % 512) / 512
  end
  
  def mtime
    @mtime
  end
  
  def mtime=(new_mtime)
    @mtime = new_mtime
  end
  
  def type
    @type
  end
  
  def type=(new_type)
    @type = new_type
  end
  
  def dest
    @dest
  end
  
  def dest=(new_dest)
    @dest = new_dest
  end
  
  def format
    @format
  end
  
  def format=(new_format)
    @format = new_format
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
  
  def user
    @user
  end
  
  def user=(new_user)
    @user = new_user
  end
  
  def group
    @group
  end
  
  def group=(new_group)
    @group = new_group
  end
  
  def major
    @major
  end
  
  def major=(new_major)
    @major = new_major
  end
  
  def minor
    @minor
  end
  
  def minor=(new_minor)
    @minor = new_minor
  end
  
  def atime
    @atime
  end
  
  def atime=(new_atime)
    @atime = new_atime
  end
  
  def ctime
    @ctime
  end
  
  def ctime=(new_ctime)
    @ctime = new_ctime
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
