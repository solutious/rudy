require File.join(File.dirname(__FILE__), 'helper')

module Rudy::Test
  class EC2 < Test::Unit::TestCase
    @@logger = StringIO.new
    @@rmach = Rudy::Machines.new(:logger => STDERR)
    @@ec2 = @@rmach.ec2
    
    def setup
#      puts @@ec2
      stop_test @@ec2.is_a?(Rudy::AWS::EC2::Instances), "We don't have an instance of Rudy::AWS::EC2"
    end
    
    
    context "EC2 Addresses" do
      should "allocate address" do
        stop_test @@ec2.addresses.list.any?, "Destroy the existing addresses"
      end
      
      should "list available Elastic IP addresses" do
        assert @@ec2.addresses.list.any?, "No addresses"
        assert @@ec2.addresses.list_as_hash.is_a?(Hash), "Not a Hash"
        assert @@ec2.addresses.list.is_a?(Array), "Not an Array"
        assert_equal 1, @@ec2.addresses.list.size, "More than one address"
      end
      
    end
    
    xcontext "EC2 Instances" do
      
      should "be no running instances" do
        instances = @@ec2.instances.list([], :running)
        assert instances.empty?, "There are instances running"
      end
      
      should "start and stop an instance" do
        # Amazon Getting Started AMI
        @instances = @@ec2.instances.create('ami-235fba4a')
        assert @instances.is_a?(Array), "Not an Array of instances"
        assert @instances.first.is_a?(Rudy::AWS::EC2::Instance), "Not an Rudy::AWS::EC2::Instance object"
      end
      
      should "allocate IP address" do
        # TODO
        
      end
      
      should "stop an instance" do
        assert @instances.is_a?(Array), "Not an Array of instances"
      end
      
    end
      
  end
end