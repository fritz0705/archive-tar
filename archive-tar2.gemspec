lib = File.expand_path("../lib/", __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name = "archive-tar2"
  s.version = "1.5"
  s.summary = "Improved TAR implementation in Ruby"
  s.authors = ["Fritz Grimpen"]
  s.email = "fritz+archive-tar@grimpen.net"
  s.files = Dir["lib/**/*.rb"]
  s.require_path = "lib"
  s.platform = Gem::Platform::RUBY
  s.homepage = "http://grimpen.net/archive-tar"
  s.license = "MIT"
end
