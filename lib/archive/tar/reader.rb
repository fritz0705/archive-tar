require "fileutils"

class Archive::Tar::Reader
  def initialize(file, parse = true)
    @file = file

    self.parse if parse
  end

  def each(base = nil, &block)
    @index.each do |i|
      block.call(*(@records[i]))
    end
  end

  def extract(dest, preserve = false, base = nil)
     raise "No such directory: #{dest}" unless File.directory?(dest)

    each(base) do |header, file|
      path = File.join(dest, header[:path])

      case header[:type]
      when :normal
        File.open(path, "wb") do |io|
          io.write file
        end
      when :link
        File.link(path, File.join(dest, header[:dest]))
      when :symbolic
        File.symlink(path, File.join(dest, header[:dest]))
      when :character
        system("mknod '#{path}' c #{header[:major]} #{header[:minor]}")
      when :block
        system("mknod '#{path}' b #{header[:major]} #{header[:minor]}")
      when :directory
        FileUtils.mkdir path
      when :fifo
        system("mknod '#{path}' p")
      end

      if preserve
        File::chmod(header[:mode], path)
        File.new(path).chown(header[:uid], header[:gid])
      end
    end
  end

  protected
  def parse
    @index = []
    @records = {}

    until @file.eof?
      read = @file.read(512)
      if read == "\0" * 512
        break
      end

      header = Archive::Tar::Format.unpack_header(read)

      size = header[:size]
      blocks = size % 512 == 0 ? size / 512 : (size + (512 - size % 512)) / 512
      content = nil

      if blocks != 0
        content = @file.read(blocks * 512)[0, size]
      end

      @index << header[:path]
      @records[header[:path]] = [ header, content ]
    end
  end
end