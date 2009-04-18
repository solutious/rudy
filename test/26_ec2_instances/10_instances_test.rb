
module Rudy::Test
  class Case_26_EC2

    context "#{name}_10 Instances" do
      
      setup do
        @ec2inst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
        @ec2add = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey, @@global.region)
        @us_ami = @@config.machines.find(:"us-east-1b", :ami)
        @eu_ami = @@config.machines.find(:"eu-west-1b", :ami)
      end
      
      should "(10) create instance" do
        stop_test @ec2inst.any?(:running), "Destroy the existing instances"
        instances = @ec2inst.create(:ami => 'ami-235fba4a', :group => "default") # Amazon Getting Started AMI
        assert instances.is_a?(Array), "Not an Array of instances"
        instances.each do |instance|
          Rudy::Utils.waiter(2, 120, @@logger) { @ec2inst.running?(instance) }
          assert instance.is_a?(Rudy::AWS::EC2::Instance), "Not an Rudy::AWS::EC2::Instance object"
        end
      end
      
          testnum = 20
          Rudy::AWS::EC2::Instances::KNOWN_STATES.each do |state|
      should "(#{testnum}) know instance is #{state}" do
        instances = @ec2inst.list(state) || []
        return skip("No instances are in #{state} state") if instances.empty?
        instances.each do |inst|
          assert @ec2inst.send("#{state}?", inst) # running?(inst)
        end
      end
          testnum += 1
          end
      
      should "(30) list instance" do
        assert @ec2inst.list.is_a?(Array), "Not an Array of instances"
        assert @ec2inst.list_as_hash.is_a?(Hash), "Not a Hash of instances"
      end
      
      should "(31) console" do
        @ec2inst.list.each do |inst|
          assert @ec2inst.console_output(inst).is_a?(String), "No console output for (#{inst.awsid})"
        end
      end
      
      should "(40) assign IP address to instance" do
        assigned = 0
        @ec2inst.list.each do |instance|
          next if instance.terminated? || instance.shutting_down?
          assigned += 1
          address = @ec2add.create
          assert @ec2add.associate(address, instance), "Did not assign"
        end
        assert assigned > 0, "No machine running"
      end
      
      
      should "(60) restart instance" do
        instances = @ec2inst.list(:running)
        instances.each do |instance|
          assert @ec2inst.restart(instance), "Did not restart"
        end
      end
      
      should "(99) destroy instance" do
        assert @ec2inst.any?(:running), "No instances running"
        instances = @ec2inst.list(:running) 
        return skip("No running instances") unless instances
        instances.each do |instance|
          assert @ec2inst.destroy(instance), "Did not destroy"
        end
      end
      
      should "(99) clean created addresses" do
        (@ec2add.list || []).each do |address|
          assert @ec2add.destroy(address), "Address not destroyed (#{address})"
        end
      end
      
    end
  end
end