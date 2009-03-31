
module Rudy::Test
  class Case_26_EC2

    xcontext "#{name} Instances" do
      
      setup do
        @us_ami = @@config.machines.find(:"us-east-1b", :ami)
        @eu_ami = @@config.machines.find(:"eu-west-1b", :ami)
      end
      
      should "(10) create instance" do
        stop_test @@ec2.instances.any?(:running), "Destroy the existing instances"
        instances = @@ec2.instances.create('ami-235fba4a') # Amazon Getting Started AMI
        assert instances.is_a?(Array), "Not an Array of instances"
        instances.each do |instance|
          assert instance.is_a?(Rudy::AWS::EC2::Instance), "Not an Rudy::AWS::EC2::Instance object"
        end
      end
      
      should "(20) list instance" do
        assert @@ec2.instances.list.is_a?(Array), "Not an Array of instances"
        assert @@ec2.instances.list_as_hash.is_a?(Hash), "Not a Hash of instances"
      end
      
      should "(30) assign IP address to instance" do
        assigned = 0
        @@ec2.instances.list.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          assigned += 1
          address = @@ec2.addresses.create
          assert @@ec2.addresses.associate(instance, address), "Did not assign"
        end
        assert assigned > 0, "No machine running"
      end
      
      should "(40) restart instance" do
        instances = @@ec2.instances.list
        instances.each do |instance|
          next unless instance.running?
          assert @@ec2.instances.restart(instance), "Did not restart"
        end
      end
      
      should "(99) destroy instance" do
        instances = @@ec2.instances.list  # nil means all states
        instances.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          assert @@ec2.instances.destroy(instance), "Did not destroy"
        end
      end
      
      should "(99) clean created addresses" do
        (@@ec2.addresses.list || []).each do |address|
          assert @@ec2.addresses.destroy(address), "Address not destroyed (#{address})"
        end
      end
      
    end
  end
end