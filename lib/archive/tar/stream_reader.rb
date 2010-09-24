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

require "archive/tar/reader"

class Archive::Tar::StreamReader < Archive::Tar::Reader
  def initialize(stream, options = {})
    options = {
      block_size: 2 ** 19,
      reload_time: 32
    }.merge(options)
    
    stream = IO.new(stream) if io.is_a? Integer
  
    if options[:compression] == :auto
      raise "Automatic compression is not available for streams"
    end
    
    tmp_file = File.new("/tmp/" + rand(500000).to_s(16) + ".tar", "w+b")
    Thread.new do
      i = 0
    
      until stream.eof?
        read = stream.read(options[:block_size])
        tmp_file.write(read)
        self.build_index if i % options[:reload_time] == 0
        i += 1
      end
      
      self.build_index
    end
    
    super(tmp_file, options)
  end
end
