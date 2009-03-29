require File.join(File.dirname(__FILE__), 'helper')

module Rudy::Test
  class EC2 < Test::Unit::TestCase
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@ec2 = @@rmach.ec2
    
    def setup
      stop_test @@ec2.is_a?(Rudy::AWS::EC2::Instances), "We don't have an instance of Rudy::AWS::EC2"
    end
    
    
    context "EC2 Addresses" do
      should "(01) create address" do
        stop_test @@ec2.addresses.list.any?, "Destroy the existing addresses"
        address = @@ec2.addresses.create
        assert address.is_a?(Rudy::AWS::EC2::Address), "Did not create"
        assert address.ipaddress.size > 0, "Address length is 0"
      end
      
      should "(02) list available addresses" do
        assert @@ec2.addresses.list.any?, "No addresses"
        assert @@ec2.addresses.list_as_hash.is_a?(Hash), "Not a Hash"
        assert @@ec2.addresses.list.is_a?(Array), "Not an Array"
        assert_equal 1, @@ec2.addresses.list.size, "More than one address"
      end
      
      should "(03) destroy address" do
        assert @@ec2.addresses.list.any?, "No addresses"
        @@ec2.addresses.list.each do |address|
          assert @@ec2.addresses.destroy(address), "Did not destroy"
        end
      end
    end
    
    context "EC2 Instances" do
      
      should "(01) create instance" do
        stop_test @@ec2.instances.any?(:running), "Destroy the existing instances"
        instances = @@ec2.instances.create('ami-235fba4a') # Amazon Getting Started AMI
        assert instances.is_a?(Array), "Not an Array of instances"
        instances.each do |instance|
          assert instance.is_a?(Rudy::AWS::EC2::Instance), "Not an Rudy::AWS::EC2::Instance object"
        end
      end
      
      should "(02) list instance" do
        assert @@ec2.instances.list.is_a?(Array), "Not an Array of instances"
        assert @@ec2.instances.list_as_hash.is_a?(Hash), "Not a Hash of instances"
      end
      
      should "(03) assign IP address to instance" do
        @@ec2.instances.list.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          address = @@ec2.addresses.create
          assert @@ec2.addresses.associate(instance, address), "Did not assign"
        end
      end
      
      should "(04) restart instance" do
        instances = @@ec2.instances.list
        instances.each do |instance|
          next unless instance.running?
          assert @@ec2.instances.restart(instance), "Did not restart"
        end
      end
      
      should "(05) destroy instance" do
        instances = @@ec2.instances.list  # nil means all states
        instances.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          assert @@ec2.instances.destroy(instance), "Did not destroy"
        end
      end
      
    end
      
  end
end