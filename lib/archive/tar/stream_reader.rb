=begin license
Copyright 2010 Fritz Conrad Grimpen. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of
      conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice, this list
      of conditions and the following disclaimer in the documentation and/or other materials
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY FRITZ CONRAD GRIMPEN ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those of the
authors and should not be interpreted as representing official policies, either expressed
or implied, of Fritz Conrad Grimpen.
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
