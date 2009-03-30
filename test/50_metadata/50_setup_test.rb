require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  class MetaData < Test::Unit::TestCase
    include Rudy::AWS
    
    @@logger = StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@global = @@rmach.global
    
    
    context "(50) #{name} Setup" do
      
    end
    
    at_exit {
      @@logger.rewind
      puts @@logger.read
    }
  end
end