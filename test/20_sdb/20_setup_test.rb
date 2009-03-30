require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class SimpleDB < Test::Unit::TestCase
    include Rudy::AWS
    
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@zone = @@rmach.global.zone
    
    context "(20) #{name} Setup" do
      should "(00) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Machines), "We don't have an instance of Rudy::Machines (#{@@rmach})"
        stop_test !@@sdb.is_a?(Rudy::AWS::SimpleDB), "We don't have an instance of Rudy::AWS::EC2 (#{@@ec2})"
      end
      should "(01) be zone" do
        stop_test !@@zone || @@zone.empty?, "No zone"
      end
    end
  end
  
end