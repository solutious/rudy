
libdir = File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift libdir
%w{amazon-ec2 drydock caesars rye}.each { |dir| $: << File.join(File.dirname(__FILE__), '..', '..', dir, 'lib') }

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
def xstop_test(*args, &ignore)
  #puts %Q(Skipping stop_test: %s "%s") % [args.last.color(:blue), args.first.color(:blue).bright]
end

def skip(msg)
  puts "%s (%s)" % ["SKIP".color(:blue).bright, msg]
  :skip # this doesn't do anything, but I would like it to!
end

def xshould(*args, &ignore)
  puts %Q(Skipping test: %s "%s") % [@name.color(:blue), args.first.color(:blue).bright]
end
def xcontext(*args, &ignore)
  puts %q(Skipping context: "%s") % (@name || args.first).color(:blue).bright
end