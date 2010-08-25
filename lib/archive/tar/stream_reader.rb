require "fileutils"
require "archive/tar/new_reader"

class Archive::Tar::StreamReader
  def initialize(stream, options = {})
    options = {
      compression: :none,
      block_offset: 0,
      block_amount: 0
    }.merge(options)
    
    raise "Auto Compression is not available for StreamReader" if options[:compression] = :auto
    
    stream = IO.new(stream) if stream.is_a? Integer
    stream = File.new(stream) if stream.is_a? String
    
    @stream = stream
    @options = options
    
    load_entries
  end
  
  def stream
    @stream
  end
  
  def stat(file)
    result = @stats[normalize_path(file)]
    raise NoSuchEntryError.new(file) if result == nil
    
    result
  end
  
  def read(file)
    file = normalize_path(file)
    raise NoSuchEntryError.new(file) unless @entries.key? file
    
    @entries[file]
  end
  
  def [](file)
    read(file)
  end
  
  def has_entry?(name)
    @entries.key? name
  end
  
  def entry?(name)
    has_entry? name
  end
  
  def each(&block)
    @stats.each do |file|
      block.call(file, -1)
    end
  end
  
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

    each do |header|
      entry = header[:path]
      ndest = File.join(dest, entry)
      offset = -1
      
      _extract(header, offset, ndest, options)
    end
  end

  def extract(source, dest, options = {})
    options = {
      :recursive => true,
      :preserve => false,
      :override => false
    }.merge(options)

    header = stat(source)
    _extract(header, dest, options)

    if header[:type] == :directory && options[:recursive]
      each do |header|
        entry = header[:path]
        if entry[0, source.length] == source && entry != source
          extract(entry, File.join(dest, entry.sub(source, "")), options)
        end
      end
    end
  end
  
  protected
  def normalize_path(path)
    while path[-1] == "/"
      path = path[0..-2]
    end
    
    while path[0] == "/"
      path = path[1..-1]
    end
    
    path
  end
  
  def load_entries
    stream = @stream
    @entries = {}
    @stats = {}
    
    blocks_limit = @options[:block_amount]
    
    stream.seek(@options[:block_offset] * 512, IO::SEEK_CUR) if @options[:block_offset] > 0
    
    block_num = 0
    until stream.eof? && ( block_num < blocks_limit || blocks_limit == 0 )
      header = stream.read(512)
      header = Archive::Tar::Format::unpack_header(header)
      header[:path] = normalize_path(header[:path])
      
      content = stream.read(header[:blocks])[header[:size]]
      
      @entries[header[:path]] = content
      @stats[header[:path]] = header
      
      block_num += 1
    end
  end
  
  def export_to_file(source, length, destination)
    destination = File.new(destination, "w+b") if destination.is_a?(String)
    destination.write(self[source])
    true
  end
  
  def _extract(header, dest, options)
    if !options[:override] && File::exists?(dest)
      return
    end

    case header[:type]
    when :normal
      export_to_file(header[:path], header[:size], dest)
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
end
