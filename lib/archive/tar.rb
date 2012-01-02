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

module Archive
  module Tar
    VERSION = "1.5.0"
    
    def normalize_path(path)
      path = path.gsub("\\", "/")
    
      while path[-1] == "/"
        path = path[0..-2]
      end
      
      while path[0] == "/"
        path = path[1..-1]
      end
      
      solve_path(path.gsub(/[\/]{2,}/, "/"))
    end
    
    def solve_path(path)
      path_parts = path.split("/")
      realpath = []
      
      path_parts.each do |i|
        if i == "."
          next
        end
        
        if i == ".."
          realpath = realpath[1..-2]
          realpath = [] if realpath == nil
          next
        end
        
        realpath << i
      end
      
      realpath.join("/")
    end
    
    def join_path(*files)
      absolute = files[0][0] == "/"
      files = files.map do |element|
        normalize_path element
      end
      
      new_path = files.join("/")
      new_path = "/" + new_path if absolute
      
      new_path
    end
  end
end

require "archive/tar/format.rb"
require "archive/tar/reader.rb"
require "archive/tar/writer.rb"
require "archive/tar/stat.rb"
require "archive/tar/stream_reader.rb"
