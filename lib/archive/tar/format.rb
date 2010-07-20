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
        :name => header[345, 155].strip + header[0, 100].strip,
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
  end
end