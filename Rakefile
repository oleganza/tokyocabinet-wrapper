require "rake"
require "rake/clean"
require "rake/gempackagetask"
require "rake/rdoctask"
require "rake/testtask"
require "spec/rake/spectask"
require "fileutils"
 
def __DIR__
  File.dirname(__FILE__)
end
 
include FileUtils

require "lib/tokyocabinet-wrapper"

GEM_NAME = "tokyocabinet-wrapper"
GEM_VERSION = "1.0"
 
def sudo
  ENV['TC_SUDO'] ||= "sudo"
  sudo = windows? ? "" : ENV['TC_SUDO']
end
 
def windows?
  (PLATFORM =~ /win32|cygwin/) rescue nil
end
 
def install_home
  ENV['GEM_HOME'] ? "-i #{ENV['GEM_HOME']}" : ""
end
 
##############################################################################
# Packaging & Installation
##############################################################################
CLEAN.include ["**/.*.sw?", "pkg", "lib/*.bundle", "*.gem", "doc/rdoc", ".config", "coverage", "cache"]
 
desc "Run the specs."
task :default => :specs
 
task :tokyocabinet => [:clean, :rdoc, :package]
 
spec = Gem::Specification.new do |s|
  s.name = GEM_NAME
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.author = "Oleg Andreev"
  s.email = "oleganza@gmail.com"
  s.homepage = "http://strokedb.com"
  s.summary = "A user-friendly object-oriented wrapper for TokyoCabinet HDB & BDB."
  s.bindir = "bin"
  s.description = s.summary
  s.executables = %w( )
  s.require_path = "lib"
  s.files = %w( README Rakefile ) + Dir["{spec,lib}/**/*"]
 
  # rdoc
  s.has_rdoc = true
  s.extra_rdoc_files = %w( README )
  #s.rdoc_options += RDOC_OPTS + ["--exclude", "^(app|uploads)"]
 
  # Dependencies
  # s.add_dependency "something"
  # Requirements
  s.required_ruby_version = ">= 1.8.4"
end
 
Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end
 
desc "Run :package and install the resulting .gem"
task :install => :package do
  sh %{#{sudo} gem install #{install_home} --local pkg/#{GEM_NAME}-#{GEM_VERSION}.gem --no-rdoc --no-ri}
end
 
desc "Run :clean and uninstall the .gem"
task :uninstall => :clean do
  sh %{#{sudo} gem uninstall #{NAME}}
end
