require "fileutils"

class Archive::Tar::Reader
  def self.detect_compression(filename)
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

  def initialize(file, options = {})
    options = {
      :compression => :auto,
      :tmpdir => "/tmp",
      :block_size => 2 ** 19,
      :read_limit => 2 ** 19
    }.merge(options)

    options[:compression] = Archive::Tar::Reader.detect_compression(file.path) if options[:compression] == :auto

    case options[:compression]
    when :none
      @file = file
    when :bzip2
      @file = _tmp_file_with_pipe("/usr/bin/env bzip2 -d -c -f", file, options[:tmpdir])
    when :gzip
      begin
        require 'zlib'
        @file = Zlib::GzipReader.new(file)
      rescue LoadError
        @file = _tmp_file_with_pipe("/usr/bin/env gzip -d -c -f", file, options[:tmpdir])
      end
    when :lzma
      @file = _tmp_file_with_pipe("/usr/bin/env lzma -d -c -f", file, options[:tmpdir])
    when :xz
      @file = _tmp_file_with_pipe("/usr/bin/env xz -d -c -f", file, options[:tmpdir])
    end

    @block_size = options[:block_size]
    @read_limit = options[:read_limit]

    write_index
  end

  def file
    @file
  end

  def index
    @index
  end

  def each(&block)
    @index.each_value do |array|
      block.call(*(array))
    end
  end

  def extract_all(dest, options = {})
    options[:recursive] = true

    unless File::exists? dest
      FileUtils::mkdir_p dest
    end

    unless File.directory? dest
      raise "No such directory: #{dest}"
    end

    @index.each_key do |entry|
      if !entry.include?("/") || entry.count("/") == 1
        extract(entry, File.join(dest, entry), options)
      end
    end
  end

  def extract(source, dest, options = {})
    options = {
      :recursive => true,
      :preserve => false,
      :override => false
    }.merge(options)
    unless @index.key? source
      raise "No such file: #{source}"
    end

    header, offset = @index[source]
    _extract(header, offset, dest, options)

    if header[:type] == header[:directory] && options[:recursive]
      @index.each_key do |entry|
        if entry[0, source.length] == source && entry != source
          extract(entry, File.join(dest, entry.sub(source, "")), options)
        end
      end
    end
  end

  def [](entry)
    @index[entry]
  end

  def has_file?(entry)
    @index.key?(entry) || @index.key?(entry + "/")
  end

  def read(name)
    unless @index.key? name
      raise "No such file: #{name}"
    end

    header, offset = self[name]
    @file.seek(offset)

    @file.read(header[:size])
  end

  protected
  def write_index
    @file.rewind
    @index = {}

    until @file.eof?
      block = @file.read(512)
      if block == "\0" * 512
        break
      end

      header = Archive::Tar::Format::unpack_header(block)

      @index[header[:path]] = [ header, @file.pos ]
      @file.seek(header[:blocks] * 512, IO::SEEK_CUR)
    end
    @file.rewind
  end

  def _extract(header, offset, dest, options)
    @file.seek(offset)

    if !options[:override] && File::exists?(dest)
      return
    end

    case header[:type]
    when :normal
      io = File.new(dest, "w+b")
      if header[:size] > @read_limit
        i = 0
        while i < header[:size]
          io.write(@file.read(@block_size))
          i += @block_size
        end
      else
        io.write(@file.read(header[:size]))
      end
      io.close
    when :directory
      if !File.exists? dest
        Dir.mkdir(dest)
      end
    when :symbolic
      File.symlink(header[:dest], dest)
    when :link
      if header[:dest][0] == "/"
        FileUtils.touch(header[:dest])
      else
        FileUtils.touch(realpath("#{dest}/../#{header[:dest]}"))
      end

      File.link(header[:dest], dest)
    when :block
      system("mknod '#{dest}' b #{header[:major]} #{header[:minor]}")
    when :character
      system("mknod '#{dest}' c #{header[:major]} #{header[:minor]}")
    when :fifo
      system("mknod '#{dest}' p #{header[:major]} #{header[:minor]}")
    end

    if options[:preserve]
      File.chmod(header[:mode], dest)
      File.chown(header[:uid], header[:gid], dest)
    end
  end

  private
  def _tmp_file_with_pipe(command, io, tmpdir)
    pipe = IO.popen(command, "a+b")
    pipe.write(io.read)
    pipe.close_write
    file = File.new(File.join(tmpdir, rand(500512) + ".atmp"), "rb")
    file.write(pipe.read)
    pipe.close
    file.close_write

    return file
  end

  def realpath(string)
    real_path = []
    string.split("/").each do |i|
      if i == "."
        next
      elsif i == ".."
        real_path = real_path[0..-2]
        next
      end

      real_path << i
    end

    return real_path.join("/")
  end
end