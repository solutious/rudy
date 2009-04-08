
module Rudy::Test
  class Case_50_Commands
    
    context "#{name}_50 Machines" do
      
      setup do
        
        @rmach = Rudy::Machines.new(:logger => @@logger)
        stop_test !@rmach.is_a?(Rudy::Machines), "We need Rudy::Machines (#{@rmach})"
        
        @rgroup = Rudy::Groups.new(:logger => @@logger)
        stop_test !@rgroup.is_a?(Rudy::Groups), "We need Rudy::Machines (#{@rgroup})"

        @rkey = Rudy::KeyPairs.new(:logger => @@logger)
        stop_test !@rkey.is_a?(Rudy::KeyPairs), "We need Rudy::KeyPairs (#{@rkey})"
        
        @rvol = Rudy::Volumes.new(:logger => @@logger)
        stop_test !@rvol.is_a?(Rudy::Volumes), "We need Rudy::Volumes (#{@rvol})"
        
        @rkey.global.environment = :test
        @rgroup.global.environment = :test
        @rmach.global.environment = :test
      end
      
      should "(01) have a test keypair" do
        kp = @rkey.create
        assert kp.is_a?(Rudy::AWS::EC2::KeyPair), "No keypair for #{@rkey.current_machine_group}"
        assert File.exists?(@rkey.path), "No private key"
      end
      
      should "(05) have a security group" do
        stop_test @rgroup.exists?(@rmach.current_machine_group), "Destroy existing groups first"
        @rgroup.any?
        
        assert @rmach.current_machine_group.is_a?(String), "No current machine group defined"
        
        group = @rgroup.create
        
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group"
        assert @rgroup.exists?(@rmach.current_machine_group), "No matching security group"
      end
      
      
      should "(10) create a machine" do
        stop_test @rmach.running?, "Shutdown the machines running in #{@rmach.current_machine_group}"
        instances = @rmach.create
        assert instances.is_a?(Array), "instances is not an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is not a Rudy::AWS::EC2::Instance (#{instances.first.class})"
        assert_equal 1, instances.size, "#{instances.size} instances were started"
      end
      
      
      should "(20) list instances in machine group" do
        assert @rmach.running?, "No machines running"
        instances = @rmach.list(:running)
        assert instances.is_a?(Array), "instances is not an Array"
        assert instances.first.is_a?(Rudy::AWS::EC2::Instance), "instance is not a Rudy::AWS::EC2::Instance"
      end

      should "(30) check console output" do
        assert @rmach.console.is_a?(String), "No console output"
      end
      
      should "(45) attach disk to instance" do
        volume = @rvol.create(volume_size)
        instances = @rmach.list(:running)
        assert volume.available?, "Volume not available"
        assert @rvol.attach(volume, instances.first), "Volume #{volume.awsid} not attached to #{instance.awsid}"
        assert @rvol.detach(volume), "Volume not detached (#{volume.awsid})"
        assert @rvol.destroy(volume), "Volume not destroyed (#{volume.awsid})"
      end
      
      should "(90) destroy machines" do
        assert @rmach.running?, "No machines running"
        assert @rmach.destroy, "Group not destroyed"
      end
      
      should "(95) destroy machine group" do
        # We can't delete the machine group until all instances are terminated
        Rudy.waiter(2, 60, @@logger) { !@@ec2.instances.any?(:running) }
        @rgroup.list do |group|
          next if group.name == 'default' # The default group is invisible
          assert @rgroup.destroy(group.name), "Did not destroy #{group.name}"
        end
      end
      
      
      should "(96) destroy test keypair" do
        # We can't delete the keypair until all instances are terminated
        Rudy.waiter(2, 60, @@logger) { !@@ec2.instances.any?(:running) }
        assert @rkey.destroy, "Keypair (#{@rkey.name}) not destroyed"
      end
      
    end
    

  end
end


# assert_equal 'John Doe', @user.full_name
# assert_same_elements([:a, :b, :c], [:c, :a, :b])
# assert_contains(['a', '1'], /\d/)
# assert_contains(['a', '1'], 'a')
