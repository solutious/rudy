require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  class Commands < Test::Unit::TestCase
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@rgroup = Rudy::Groups.new(:logger => @@logger)
    
    def setup
      
    end
    
    def teardown
      #if @logger.is_a?(StringIO)
      #  @logger.rewind
      #  output = @logger.read
      #  puts $/, "Rudy output:".bright, output unless output.empty?
      #end
    end
  end
end