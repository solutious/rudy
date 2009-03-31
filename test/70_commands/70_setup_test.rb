require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  class TC_70_Commands < Test::Unit::TestCase
    include Rudy::AWS
    
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@rgroup = Rudy::Groups.new(:logger => @@logger)
    
  end
end