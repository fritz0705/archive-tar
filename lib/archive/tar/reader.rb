require "fileutils"

class Archive::Tar::Reader
  def self.detect_compression_by_name(filename)
    return :none unless filename.include? "."

    case filename.slice(Range.new(filename.rindex(".") + 1, -1))
    when "gz", "tgz"
      return :gzip
    when "bz2", "tbz", "tb2"
      return :bzip2
    when "xz", "txz"
      return :xz
    when "lz", "lzma", "tlz"
      return :lzma
    end

    return :none
  end

  def self.detect_compression_by_magic(io)
    io.rewind
    fb = io.read(512)
    
    if fb[257, 5] == "ustar"
      return :none
    elsif fb[0, 3] == "BZh"
      return :bzip2
    elsif fb[0, 4] == "\x1f\x8b\x08\x08"
      return :gzip
    elsif fb[0, 5] == "\x5d\x00\x00\x80\x00"
      return :lzma
    elsif fb[0, 2] == "\xfd\x37"
      return :xz
    end

    return :none
  end

  def initialize(file, compression = :auto, parse = true)
    if compression == :auto && file.is_a?(File)
      compression = Archive::Tar::Reader.detect_compression_by_name(file.path)
    elsif compression == :auto
      compression = Archive::Tar::Reader.detect_compression_by_magic(file)
    end

    case compression
    when :none
      @file = file
    when :gzip
      require 'zlib'
      @file = Zlib::GzipReader.new(file)
    when :bzip2
      @file = IO.popen("/usr/bin/env bzip2 -d -c -f", "a+b")
      @file.write(file.read)
      @file.close_write
    when :lzma
      @file = IO.popen("/usr/bin/env lzma -d -c -f", "a+b")
      @file.write(file.read)
      @file.close_write
    when :xz
      @file = IO.popen("/usr/bin/env xz -d -c -f", "a+b")
      @file.write(file.read)
      @file.close_write
    end

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

  def parse(entries = 0)
    @index = []
    @records = {}
    i = 1

    until @file.eof? && (i > entries || entires == 0)
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
      @records[header[:path]] = header

      i += 1
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
end