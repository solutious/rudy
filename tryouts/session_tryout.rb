#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')


require 'rubygems'
require 'session'
require 'net/ssh'
require 'rye'
require 'yaml'

#p Rye.command('ssh', '-i', '', '')

class Rye::Box
  def uptime
    command("uptime")
  end
  def sleep
    command("sleep", 5)
  end
end


rbox = Rye::Box.new('ec2-174-129-173-3.compute-1.amazonaws.com', 'root')
rbox2 = Rye::Box.new('ec2-174-129-173-3.compute-1.amazonaws.com', 'root')
rbox.add_keys('/Users/delano/Projects/git/rudy/.rudy/key-test-app.private')
rbox.connect
puts rbox.date
puts rbox.sleep
rbox.disconnect
#>> 

__END__


rgroup = Rye::Group.new('root', 'keydir/file')
rgroup.add_hosts('ec2-174-129-173-3.compute-1.amazonaws.com')
rgroup.command('hostname')



#shell = Session::Shell.new 

#p shell.execute('ssh -T -t -i /Users/delano/Projects/git/rudy/.rudy/key-test-app.private root@ec2-174-129-82-193.compute-1.amazonaws.com')

#Net::SSH.configuration_for(localhost, ssh_options.fetch(:config, true)).merge(ssh_options)