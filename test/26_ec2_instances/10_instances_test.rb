
module Rudy::Test
  class Case_26_EC2

    context "#{name}_10 Instances" do
      
      setup do
        @us_ami = @@config.machines.find(:"us-east-1b", :ami)
        @eu_ami = @@config.machines.find(:"eu-west-1b", :ami)
      end
      
      should "(10) create instance" do
        stop_test @@ec2.instances.any?(:running), "Destroy the existing instances"
        instances = @@ec2.instances.create(:ami => 'ami-235fba4a') # Amazon Getting Started AMI
        assert instances.is_a?(Array), "Not an Array of instances"
        instances.each do |instance|
          Rudy.waiter(2, 120, @@logger) { @@ec2.instances.running?(instance) }
          assert instance.is_a?(Rudy::AWS::EC2::Instance), "Not an Rudy::AWS::EC2::Instance object"
        end
      end
      
          testnum = 20
          Rudy::AWS::EC2::Instances::KNOWN_STATES.each do |state|
      should "(#{testnum}) know instance is #{state}" do
        instances = @@ec2.instances.list(state) || []
        return skip("No instances are in #{state} state") if instances.empty?
        instances.each do |inst|
          assert @@ec2.instances.send("#{state}?", inst) # running?(inst)
        end
      end
          testnum += 1
          end
      
      should "(30) list instance" do
        assert @@ec2.instances.list.is_a?(Array), "Not an Array of instances"
        assert @@ec2.instances.list_as_hash.is_a?(Hash), "Not a Hash of instances"
      end
      
      should "(31) console" do
        @@ec2.instances.list.each do |inst|
          assert @@ec2.instances.console_output(inst).is_a?(String), "No console output for (#{inst.awsid})"
        end
      end
      
      should "(40) assign IP address to instance" do
        assigned = 0
        @@ec2.instances.list.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          assigned += 1
          address = @@ec2.addresses.create
          assert @@ec2.addresses.associate(instance, address), "Did not assign"
        end
        assert assigned > 0, "No machine running"
      end
      
      
      should "(60) restart instance" do
        instances = @@ec2.instances.list(:running)
        instances.each do |instance|
          assert @@ec2.instances.restart(instance), "Did not restart"
        end
      end
      
      should "(99) destroy instance" do
        assert @@ec2.instances.any?(:running), "No instances running"
        instances = @@ec2.instances.list(:running) 
        return skip("No running instances") unless instances
        instances.each do |instance|
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