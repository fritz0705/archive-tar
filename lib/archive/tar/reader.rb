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

require "fileutils"
require "archive/tar/format"

class Archive::Tar::NoSuchEntryError < RuntimeError
end

class Archive::Tar::Reader
  include Archive::Tar

  def initialize(stream, options = {})
    options = {
      compression: :auto,
      tmpdir: "/tmp",
      block_size: 2 ** 19,
      read_limit: 2 ** 19,
      cache: true,
      cache_size: 16,
      max_cache_size: 2 ** 19,
      generate_index: true,
      use_normalized_paths: true,
    }.merge(options)
    
    if stream.is_a? String
      stream = File.new(stream)
    end
    
    @options = options
    @stream = _generate_compressed_stream(stream, options[:compression])
    @cache_candidates = []
    @cache = {}
    
    build_index if options[:generate_index]
  end
  
  def stream
    @stream
  end
  
  def index
    @index
  end
  
  def stat(file, exception = true)
    if @options[:use_normalized_paths]
      result = @index[normalize_path(file)]
    else
      result = @index[file]
    end
    raise NoSuchEntryError.new(file) if result == nil && exception
    
    result
  end
  
  def [](file)
    stat(file, false)
  end
  
  def has_entry?(file)
    @index.key? file
  end
  
  def entry?(file)
    has_entry? file
  end
  
  def each(&block)
    @index.each do |key, value|
      block.call(*(value))
    end
  end
  
  def read(name, no_cache = false)
    header, offset = stat(name)
    
    if @options[:cache] && header[:size] <= @options[:max_cache_size] && !no_cache
      @cache_candidates << name
      rebuild_cache
    end
    
    if @cache.key? name && !no_cache
      return @cache[name]
    end
    
    @stream.seek(offset)
    @stream.read(header[:size])
  end
  
  # Extract all files to /dest/ directory
  def extract_all(dest, options = {})
    options = {
      :preserve => false,
      :override => false
    }.merge(options)
  
    unless File::exists? dest
      FileUtils::mkdir_p dest
    end

    unless File.directory? dest
      raise "No such directory: #{dest}"
    end

    @index.each_key do |entry|
      ndest = File.join(dest, entry)
      header, offset = @index[entry]
      
      _extract(header, offset, ndest, options)
    end
  end

  # Extract file from /source/ to /dest/
  def extract(source, dest, options = {})
    options = {
      recursive: true,
      preserve: false,
      override: false
    }.merge(options)
    unless @index.key? source
      raise NoSuchEntryError.new(source)
    end

    header, offset = @index[source]
    _extract(header, offset, dest, options)

    if header[:type] == :directory && options[:recursive]
      @index.each_key do |entry|
        if entry[0, source.length] == source && entry != source
          extract(entry, File.join(dest, entry.sub(source, "")), options)
        end
      end
    end
  end
  
  # Build new index of files
  def build_index
    new_index = {}
    
    @stream.rewind
    
    until @stream.eof?
      raw_header = @stream.read(512)
      break if raw_header == "\0" * 512
      
      header = Archive::Tar::Format::unpack_header(raw_header)
      if @options[:use_normalized_paths]
        header[:path] = normalize_path(header[:path])
      end
      
      unless header[:type] == :pax_global_header
        new_index[header[:path]] = [ header, @stream.tell ]
      end
      
      @stream.seek(header[:blocks] * 512, IO::SEEK_CUR)
    end
    
    @index = new_index
  end
  
  protected
  def rebuild_cache
    return nil unless @options[:cache]
    
    cache_count = {}
    @cache_candidates.each do |candidate|
      cache_count[candidate] = 0 unless cache_count.key? candidate
      cache_count[candidate] += 1
    end
    cache_count_sorted = cache_count.sort do |pair_1, pair_2|
      (pair_1[1] <=> pair_2[1]) * -1
    end
    
    puts cache_count_sorted
    
    @cache = {}
    i = 0
    cache_count_sorted.each do |tupel|
      if i >= @options[:cache_size]
        break
      end
      
      @cache[tupel[0]] = read(tupel[0], true)
      i += 1
    end
  end
  
  def export_to_file(offset, length, source, destination)
    destination = File.new(destination, "w+b") if destination.is_a?(String)
    
    if @options[:max_cache_size] >= length && @options[:cache]
      @cache_candidates << source
      rebuild_cache
    end
    
    if @cache.key? source
      destination.write(@cache[source])
      return true
    end
    
    @stream.seek(offset)
    
    if length <= @options[:read_limit]
      destination.write(@stream.read(length))
      return true
    end
    
    i = 0
    while i < length
      destination.write(@stream.read(@options[:block_size]))
      i += @options[:block_size]
    end
    
    true
  end
  
  def _extract(header, offset, dest, options)
    if !options[:override] && File::exists?(dest)
      return
    end

    case header[:type]
    when :normal
      export_to_file(offset, header[:size], header[:path], dest)
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
  def _detect_compression(filename)
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
  
  def _generate_compressed_stream(stream, compression)
    if compression == :auto
      if stream.is_a? File
        compression = _detect_compression(stream.path)
      else
        compression = :none
      end
    end
    
    programs = {
      gzip: "gzip -d -c -f",
      bzip2: "bzip2 -d -c -f",
      lzma: "lzma -d -c -f",
      xz: "xz -d -c -f"
    }
    
    unless programs.key? compression
      return stream
    end
    
    io = IO::popen("/usr/bin/env #{programs[compression]}", "a+b")
    new_file = File.open("#{@options[:tmpdir]}/#{rand(500512)}", "w+b")
    Thread.new do
      until stream.eof?
        io.write(stream.read(@options[:block_size]))
      end
      
      io.close_write
    end
    
    until io.eof?
      new_file.write(io.read(@options[:block_size]))
    end
    
    new_file
  end
end
