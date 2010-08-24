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
    "I" => :index
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
      
      header_hash = {}
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
      result = {
        path: header[345, 155].strip + header[0, 100].strip,
        mode: header[100, 8].oct,
        uid: header[108, 8].oct,
        gid: header[116, 8].oct,
        size: header[124, 12].oct,
        mtime: Time.at(header[136, 12].oct),
        cksum: header[148, 6].oct,
        type: DEC_TYPES[header[156]],
        dest: header[157, 100].strip,
        ustar: header[257, 6] == "ustar ",
        version: header[263, 2].oct,
        user: header[265, 32].strip,
        group: header[297, 32].strip,
        major: header[329, 8].oct,
        minor: header[337, 8].oct,
      }
      result[:blocks] = blocks_for_bytes(result[:size])
      result
    end
    
    def detect_type(header)
      return :ustar if header[257, 6] == "ustar0"
      return :gnu if header[257, 6] == "ustar "
      
      :old_style
    end

    ## TODO: Implement checksum calculator
    def pack_header(hash)
      if hash[:path].length > 100
        path = hash[:path][100..-1]
        prefix = hash[:path][0, 100]
      else
        path = hash[:path]
        prefix = ""
      end

      path.ljust(100, "\0") +
        hash[:mode].to_s(8).rjust(8, "0") +
        hash[:uid].to_s(8).rjust(8, "0") +
        hash[:gid].to_s(8).rjust(8, "0") +
        hash[:size].to_s(8).rjust(8, "0") +
        hash[:mtime].to_i.to_s(8).rjust(8, "0") +
        hash[:cksum].to_s(8).rjust(6, "0") + "\0 " +
        ENC_TYPES[hash[:type]] +
        hash[:dest].ljust(100, "\0") +
        "ustar 00" +
        hash[:user].ljust(32, "\0") +
        hash[:group].ljust(32, "\0") +
        hash[:major].to_s(8).rjust(8, "0") +
        hash[:minor].to_s(8).rjust(8, "0") +
        prefix.ljust(155, "\0") +
        "\0" * 12
    end
    
    def blocks_for_bytes(bytes)
      bytes % 512 == 0 ? bytes / 512 : (bytes + 512 - bytes % 512) / 512
    end
  end
end
