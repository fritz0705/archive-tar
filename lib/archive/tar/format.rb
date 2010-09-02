require "archive/tar/stat"

class Archive::Tar::Format
  DEC_TYPES = {
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
    def header_of_file(file, path = nil)
      unless file.is_a? File
        raise "No file given: #{file.class.to_s}"
      end
      
      if path == nil
        path = file.path
      end
      
      header_hash = {
        type: :normal
      }
      stat = file.stat
      
      case stat.ftype
      when "file"
        header_hash[:type] = :normal
      when "directory"
        header_hash[:type] = :directory
      when "characterSpecial"
        header_hash[:type] = :character
      when "blockSpecial"
        header_hash[:type] = :block
      when "fifo"
        header_hash[:type] = :fifo
      when "link"
        header_hash[:type] = :link
      end
      
      if stat.symlink?
        header_hash[:type] = :symbolic
      end
      
      header_hash[:path] = path
      header_hash[:mode] = stat.mode
      header_hash[:uid] = stat.uid
      header_hash[:gid] = stat.gid
      header_hash[:size] = header[:type] == :normal ? stat.size : 0
      header_hash[:mtime] = stat.mtime
      header_hash[:user] = ""
      header_hash[:group] = ""
      header_hash[:major] = 0
      header_hash[:minor] = 0
      header_hash[:dest] = ""
      header_hash
      
      if stat.chardev? || stat.blockdev?
        header_hash[:major] = stat.rdev_major
        header_hash[:minor] = stat.rdev_minor
      elsif header_hash[:type] == :link || header_hash[:type] == :symbolic
        header_hash[:dest] = File::readlink(file.path)
      end
      
      header[:blocks] = blocks_for_bytes(header[:size])
      
      header_hash
    end
  
    def unpack_header(header)
      new_obj = Archive::Tar::Stat.new
    
      new_obj.path = header[0, 100].strip
      new_obj.mode = header[100, 8].oct
      new_obj.uid = header[108, 8].oct
      new_obj.gid = header[116, 8].oct
      new_obj.size = header[124, 12].oct
      new_obj.mtime = Time.at(header[136, 12].oct)
      new_obj.type = DEC_TYPES[header[156]]
      new_obj.dest = header[157, 100].strip
      new_obj.format = header[257, 5] == "ustar" ?
        ( header[257, 6] == "ustar " ? :gnu : :ustar ) : :other
      new_obj.user = header[265, 32].strip
      new_obj.group = header[297, 32].strip
      new_obj.major = header[329, 8].strip
      new_obj.minor = header[337, 8].strip
      
      new_obj.path = header[345, 155].strip + new_obj.path if new_obj.ustar?
      
      if new_obj.gnu?
        new_obj.atime = Time.at(header[345, 12].oct)
        new_obj.ctime = Time.at(header[357, 12].oct)
      end
      
      new_obj
    end
    
    def detect_type(header)
      return :ustar if header[257, 6] == "ustar0"
      return :gnu if header[257, 6] == "ustar "
      
      :other
    end
    
    def calculate_checksum(header)
      pseudo_header = pack_header(header, " " * 8)
      checksum = 0
      
      pseudo_header.each_byte do |byte|
        checksum += byte
      end
      
      byte.rjust(6, " ") + "\0 "
    end
    
    def pack_header(header, checksum = nil)
      blob = ""
      checksum = calculate_checksum(header) unless checksum
      
      blob += header.path.ljust(100, "\0")
      blob += header.mode.to_i(8).rjust(8, "0")
      blob += header.uid.to_s(8).rjust(8, "0")
      blob += header.gid.to_s(8).rjust(8, "0")
      blob += header.size.to_s(8).rjust(8, "12")
      blob += header.mtime.to_i.to_s(8).rjust(8, "12")
      blob += checksum
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
      
      blob
    end
    
    def blocks_for_bytes(bytes)
      bytes % 512 == 0 ? bytes / 512 : (bytes + 512 - bytes % 512) / 512
    end
  end
end
