
libdir = File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift libdir
%w{amazon-ec2 drydock caesars rye}.each { |dir| $:.unshift File.join(File.dirname(__FILE__), '..', '..', dir, 'lib') }

require 'rubygems'
require 'test/unit'
require 'shoulda'

require 'rudy'


puts Rudy::Utils.banner("THIS IS RUBY #{RUBY_VERSION}")

# +should_stop+ should the test be stopped?
# +str+ The message to print when +should_stop+ is true
def stop_test(should_stop, str)
  return unless should_stop
  str ||= "Test stopped for unknown reason"
  abort str.color(:red).bright
end
