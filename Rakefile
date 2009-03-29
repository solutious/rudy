require 'rubygems'
require 'rake/clean'
require 'rake/gempackagetask'
require 'hanna/rdoctask'
require 'rake/testtask'
require 'fileutils'
include FileUtils
 
task :default => :test
 
# TESTS ===============================================================
 
Rake::TestTask.new(:test_old) do |t|
  require 'monkeyspecdoc'
  test_files = FileList['test/**/*_test.rb'] || []
  t.test_files = test_files
  t.ruby_opts = ['-rubygems'] if defined? Gem
  t.verbose = true
#  t.warning = true
  
end

task :test do
  require 'rake/runtest'
  require 'monkeyspecdoc'  # http://jgre.org/2008/09/03/monkeyspecdoc/
  Rake.run_tests "test/**/*_test.rb"
  
end

# PACKAGE =============================================================

name = "rudy"
load "#{name}.gemspec"

version = @spec.version

Rake::GemPackageTask.new(@spec) do |p|
  p.need_tar = true if RUBY_PLATFORM !~ /mswin/
end

task :release => [ :rdoc, :package ] do
  $: << File.join(File.dirname(__FILE__), 'lib')
  require "rudy"
  abort if Drydock.debug?
end

task :install => [ :rdoc, :package ] do
	sh %{sudo gem install pkg/#{name}-#{version}.gem}
end

task :uninstall => [ :clean ] do
	sh %{sudo gem uninstall #{name}}
end


# Rubyforge Release / Publish Tasks ==================================

desc 'Publish website to rubyforge'
task 'publish:rdoc' => 'doc/index.html' do
  sh "scp -rp doc/* rubyforge.org:/var/www/gforge-projects/#{name}/"
end

desc 'Public release to rubyforge'
task 'publish:gem' => [:package] do |t|
  sh <<-end
    rubyforge add_release -o Any -a CHANGES.txt -f -n README.rdoc #{name} #{name} #{@spec.version} pkg/#{name}-#{@spec.version}.gem &&
    rubyforge add_file -o Any -a CHANGES.txt -f -n README.rdoc #{name} #{name} #{@spec.version} pkg/#{name}-#{@spec.version}.tgz 
  end
end


Rake::RDocTask.new do |t|
	t.rdoc_dir = 'doc'
	t.title    = @spec.summary
	t.options << '--line-numbers' <<  '-A cattr_accessor=object'
	t.options << '--charset' << 'utf-8'
	t.rdoc_files.include('LICENSE.txt')
	t.rdoc_files.include('README.rdoc')
	t.rdoc_files.include('CHANGES.txt')
	t.rdoc_files.include('bin/*')
	t.rdoc_files.include('lib/*.rb')
	t.rdoc_files.include('lib/**/*.rb')
end

CLEAN.include [ 'pkg', '*.gem', '.config', 'doc' ]



