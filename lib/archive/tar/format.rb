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

require "archive/tar/stat"

class Archive::Tar::Format
  DEC_TYPES = {
    "\0" => :normal,
    "0" => :normal,
    "1" => :link,
    "2" => :symbolic,
    "3" => :character,
    "4" => :block,
    "5" => :directory,
    "6" => :fifo,
    "7" => :reserved,
    "I" => :index,
    "g" => :pax_global_header
  }

  ENC_TYPES = DEC_TYPES.invert
  
  class << self
    # Remove all NUL bytes at the end of a string
    def strip_nuls(string)
      until string[-1] != "\0"
        string = string[0..-2]
      end
      
      string
    end
  
    # Transform tar header to Stat
    def unpack_header(header)
      new_obj = Archive::Tar::Stat.new
    
      new_obj.path = strip_nuls(header[0, 100])
      new_obj.mode = header[100, 8].oct
      new_obj.uid = header[108, 8].oct
      new_obj.gid = header[116, 8].oct
      new_obj.size = header[124, 12].oct
      new_obj.mtime = Time.at(header[136, 12].oct)
      new_obj.checksum = header[148, 8].oct
      new_obj.type = DEC_TYPES[header[156]]
      new_obj.dest = strip_nuls(header[157, 100])
      new_obj.format = header[257, 5] == "ustar" ?
        ( header[257, 6] == "ustar " ? :gnu : :ustar ) : :other
      new_obj.user = strip_nuls(header[265, 32])
      new_obj.group = strip_nuls(header[297, 32])
      new_obj.major = header[329, 8].oct
      new_obj.minor = header[337, 8].oct
      
      new_obj.path = header[345, 155].strip + new_obj.path if new_obj.ustar?
      
      if new_obj.gnu?
        new_obj.atime = Time.at(header[345, 12].oct)
        new_obj.ctime = Time.at(header[357, 12].oct)
      end
      
      new_obj
    end
    
    # Detect type of tar file by header
    def detect_type(header)
      return :ustar if header[257, 6] == "ustar0"
      return :gnu if header[257, 6] == "ustar "
      
      :other
    end
    
    # Generate checksum with header
    def calculate_checksum(header)
      checksum = 0
      
      header.each_byte do |byte|
        checksum += byte
      end
      
      checksum.to_s(8).rjust(6, " ") + "\0 "
    end
    
    # Pack header from Stat
    def pack_header(header)
      blob = ""
      
      blob += header.path.ljust(100, "\0")
      blob += header.mode.to_s(8).rjust(8, "0")
      blob += header.uid.to_s(8).rjust(8, "0")
      blob += header.gid.to_s(8).rjust(8, "0")
      blob += header.size.to_s(8).rjust(12, "0")
      blob += header.mtime.to_i.to_s(8).rjust(12, "0")
      blob += " " * 8
      blob += ENC_TYPES[header.type]
      blob += header.dest.ljust(100, "\0")
      
      case header.format
      when :ustar
        blob += "ustar\000"
      when :gnu
        blob += "ustar  \0"
      end
      
      if header.gnu? || header.ustar?
        blob += header.user.ljust(32, "\0")
        blob += header.group.ljust(32, "\0")
        blob += header.major.to_s(8).rjust(8, "0")
        blob += header.minor.to_s(8).rjust(8, "0")
        
        if header.gnu?
          blob += header.atime.to_i.to_s(8).rjust(12, "0")
          blob += header.ctime.to_i.to_s(8).rjust(12, "0")
        end
      end
      
      pad_length = 512 - blob.bytesize
      blob += "\0" * pad_length
      
      blob[148, 8] = calculate_checksum(blob)
      
      blob
    end
    
    # Calculate quantity of blocks
    def blocks_for_bytes(bytes)
      bytes % 512 == 0 ? bytes / 512 : (bytes + 512 - bytes % 512) / 512
    end
  end
end
