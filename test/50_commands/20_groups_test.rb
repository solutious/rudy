
module Rudy::Test
  class Case_50_Commands
    

    context "#{name}_20 Groups" do
      setup do
        @rgroup = Rudy::Groups.new(:logger => @@logger)
        stop_test !@rgroup.is_a?(Rudy::Groups), "We need Rudy::Groups (#{@rgroup})"
      end
      
      teardown do
        #if @@logger && @@logger.is_a?(StringIO)
        #  @@logger.rewind
        #  puts @@logger.read
        #end
      end
      
      should "(10) create a group" do
        stop_test @rgroup.any?, "Delete existing Groups"
        group = @rgroup.create
        assert group.is_a?(Rudy::AWS::EC2::Group)
        assert @rgroup.exists?(group.name), "Group not registered with Amazon"
        assert_equal group.name, @rgroup.name
        # We don't check the permissions because we do that in the lower
        # level tests for Rudy::AWS::EC2::Groups. 
      end
      
      should "(11) create a group with an arbitrary name" do
        n = "test-%s" % Rudy::Utils.strand
        group = @rgroup.create(n)

        assert group.is_a?(Rudy::AWS::EC2::Group)
        assert @rgroup.exists?(group.name), "Group #{group.name} not registered with Amazon"
        assert_equal group.name, n
      end
      
      
      should "(20) list groups" do
        assert @rgroup.any?, "No groups"
        assert @rgroup.exists?, "No #{@rgroup.name} group"
        
        kp_list = @rgroup.list
        assert kp_list.is_a?(Array), "List not an Array"
        
        kp_hash = @rgroup.list_as_hash
        assert kp_hash.is_a?(Hash), "List not a Hash"
      end
      
      should "(30) not create group if one exists" do
        assert @rgroup.exists?, "No #{@rgroup.name} Group"
        begin
          group = @rgroup.create
        rescue # Quiet, you!
        end
        assert group.nil?, "Group was still created"
      end
      
      xshould "(40) modify group permissions" do
        
      end
      
      should "(99) destroy groups" do
        assert @rgroup.exists?, "Group #{@rgroup.name} doesn't exist"
        @rgroup.list.each do |group|
          next if group.name == 'default'
          assert @rgroup.destroy(group.name), "Did not destroy #{group.name}"
        end
        assert !@rgroup.exists?, "Group #{@rgroup.name} still exists"
      end
      
      
    end
  
  
  end
end
