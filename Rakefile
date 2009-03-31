require 'rubygems'
require 'rake/clean'
require 'rake/gempackagetask'
require 'hanna/rdoctask'
require 'rake/testtask'
require 'shoulda/tasks'
require 'rake/runtest'
require 'monkeyspecdoc'  # http://jgre.org/2008/09/03/monkeyspecdoc/
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


namespace :test do
  desc 'Measures test coverage'
  task :coverage do
    rm_f "coverage"
    rm_f "coverage.data"
    rcov = "rcov -Itest --aggregate coverage.data -T -x ' rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*'"
    system("#{rcov} --html test/**/*_test.rb")
    system("open coverage/index.html") if RUBY_PLATFORM['darwin']
  end
  task :files do
    puts Dir.glob(File.join('test', '**', '*_test.rb'))
  end
  
  # Run individual test groups with: 
  # rake test:05 
  # rake test:60
  # etc...
  ('00'..'99').each do |group|
    task group.to_sym do
      Rake.run_tests "test/#{group}*/*_test.rb"
    end
    
    # And also individual test files
    # rake test:50:10
    # etc...
    ('00'..'99').each do |test|
      namespace group.to_sym do
        task test.to_sym do
          Rake.run_tests "test/#{group}*/{00,#{test}}*_test.rb"
        end
      end
    end
  end
end

task :test do

  #all_tests = Dir.glob(File.join('test', '{05,20,50}*', '*_test.rb')) || []
  #all_tests.sort.each do |file|
  #  load file
  #end
  Rake.run_tests 'test/**/*_test.rb'
end


# From: shoulda/tasks/list_tests.rake
namespace :shoulda do
  desc "List the names of the test methods in a specification like format"
  task :list_fixed do
    $LOAD_PATH.unshift("test")

    require 'test/unit'
    require 'rubygems'
    require 'active_support'

    # bug in test unit.  Set to true to stop from running.
    Test::Unit.run = true

    test_files = Dir.glob(File.join('test', '**', '*_test.rb'))
    
    test_files.each do |file|
      load file
      klass = File.basename(file, '.rb').classify
      #unless Object.const_defined?(klass.to_s)    # => raises: wrong constant name 00SetupTest
      unless Object.constants.member?(klass.to_s)  # fixed
        puts "Skipping #{klass} because it doesn't map to a Class"
        next
      end
      klass = klass.constantize

      puts klass.name.gsub('Test', '')

      test_methods = klass.instance_methods.grep(/^test/).map {|s| s.gsub(/^test: /, '')}.sort
      test_methods.each {|m| puts "  " + m }
    end
  end
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

CLEAN.include [ 'pkg', '*.gem', '.config', 'doc', 'coverage*' ]



