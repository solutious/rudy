#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')


require 'rubygems'
require 'session'
require 'net/ssh'
require 'rye'
require 'yaml'
require 'stringio'

#p Rye.command('ssh', '-i', '', '')

module Rye::Box::Commands
  def rudy(*args); command("/proj/git/rudy/bin/rudy", args);  end
end

logger = StringIO.new
rbox = Rye::Box.new('localhost', 'delano', :stderr => logger).connect
#rbox2 = Rye::Box.new('ec2-174-129-173-3.compute-1.amazonaws.com', 'root')
#rbox.add_keys('/Users/delano/Projects/git/rudy/.rudy/key-test-app.private')
#rbox.connect
#puts rbox.date
#puts rbox.pwd
puts rbox['/usr/bin'].pwd
puts rbox.uptime
puts rbox.can
puts rbox.echo '$HOME'
puts rbox.rudy('myaddress')
rbox.disconnect
#puts logger.read
#>> 

__END__


rgroup = Rye::Group.new('root', 'keydir/file')
rgroup.add_hosts('ec2-174-129-173-3.compute-1.amazonaws.com')
rgroup.command('hostname')



#shell = Session::Shell.new 

#p shell.execute('ssh -T -t -i /Users/delano/Projects/git/rudy/.rudy/key-test-app.private root@ec2-174-129-82-193.compute-1.amazonaws.com')

#Net::SSH.configuration_for(localhost, ssh_options.fetch(:config, true)).merge(ssh_options)