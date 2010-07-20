class Archive::Tar::Format
  DEC_TYPES = {
    "0" => :normal,
    "1" => :link,
    "2" => :symbolic,
    "3" => :character,
    "4" => :block,
    "5" => :directory,
    "6" => :fifo,
    "7" => :reserved
  }

  ENC_TYPES = DEC_TYPES.invert
  
  class << self
    def unpack_header(header)
      {
        :path => header[345, 155].strip + header[0, 100].strip,
        :mode => header[100, 8].oct,
        :uid => header[108, 8].oct,
        :gid => header[116, 8].oct,
        :size => header[124, 12].oct,
        :mtime => Time.at(header[136, 12].oct),
        :cksum => header[148, 6].oct,
        :type => DEC_TYPES[header[156]],
        :dest => header[157, 100].strip,
        :ustar => header[257, 5] == "ustar",
        :version => header[263, 2].oct,
        :user => header[265, 32].strip,
        :group => header[297, 32].strip,
        :major => header[329, 8].oct,
        :minor => header[337, 8].oct,
      }
    end

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
  end
end