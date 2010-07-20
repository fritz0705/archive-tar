require "fileutils"

class Archive::Tar::Reader
  def initialize(file, parse = true)
    @file = file

    self.parse if parse
  end

  def each(&block)
    @index.each do |i|
      block.call(*(@records[i]))
    end
  end

  def [](name)
    return @records[name]
  end

  def extract_all(dest, preserve = false)
    raise "No such directory: #{dest}" unless File.directory?(dest)

    each do |header, file|
      _extract(header, file, File.join(dest, header[:path]), preserve)
    end
  end

  def extract(source, dest, recursive = true, preserve = false)
    raise "No such entry: #{source}" unless @records.key? source

    header, file = @records[source]

    if header[:type] == :directory && recursive
      each do |header_1, file_1|
        if header_1[:path][0, source.length] != source
          next
        end

        puts header_1[:path]
        if header_1[:path].sub(source, "").empty?
          next
        end
        _extract(header_1, file_1, File.join(dest, header_1[:path].sub(source, "")), preserve)
      end
    else
      _extract(header, file, File.join(dest, File.basename(header[:path])), preserve)
    end
  end

  protected
  def _extract(header, file, path, preserve = false)
    case header[:type]
    when :normal
      File.open(path, "wb") do |io|
        io.write file
      end
    when :link
      File.link(path, File.join(dest, header[:dest]))
    when :symbolic
      File.symlink(header[:dest], path)
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