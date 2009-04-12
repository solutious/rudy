#!/usr/bin/ruby

# Tryout - A basic use-case
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
%w{drydock caesars rye}.each { |dir| $: << File.join(File.dirname(__FILE__), '..', '..', dir, 'lib') }

require 'rudy'


machine1 = Rudy::Machine.new
Rudy::Huxtable.change_environment(:prod)
machine2 = Rudy::Machine.new

puts machine1.name
puts machine2.name
puts machine2.s

#rmach = Rudy::Machines.new
#machine = rmach.create(:position => 1)
#machine.upload('/some/file')

