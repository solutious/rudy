require 'rubygems' if defined? Gem
 
libdir = File.join(File.dirname(__FILE__), '..', 'lib')
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)
 
require 'test/unit'
require 'shoulda'

require 'rudy'


puts Rudy.make_banner("THIS IS RUBY #{RUBY_VERSION}")

# +should_stop+ should the test be stopped?
# +str+ The message to print when +should_stop+ is true
def stop_test(should_stop, str)
  return unless should_stop
  str ||= "Test stopped for unknown reason"
  abort str.color(:red).bright
end

def xshould(*args, &ignore)
  puts "Skipping test: \"#{args.first}\"".color(:blue)
end
def xcontext(*args, &ignore)
  puts "Skipping context: \"#{args.first}\"".color(:blue)
end