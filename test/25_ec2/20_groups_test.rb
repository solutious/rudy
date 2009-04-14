
module Rudy::Test

  class Case_25_EC2
    
    def get_groups
      # Ruby 1.8 throws an undefined method error when this is at the 
      # bottom of the class
      group_list = @ec2group.list_as_hash
      # "default" cannot be deleted so we exempt it
      group_list.reject { |gname,group| gname == "default" }
    end
    
    
    context "#{name}_20 Groups" do
      setup do
        @ec2group = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
        @accountnum = @@config.accounts.aws.accountnum
      end
      
      should "(00) not be existing groups" do
        
        group_list = get_groups
        stop_test !group_list.empty?, "Destroy the existing groups (#{group_list.keys.join(', ')})"
        stop_test !@accountnum, "Need an account number for group authorization"
      end
      
      should "(01) create group with name" do
        group_list = get_groups
        test_name ||= 'test-' << Rudy::Utils.strand
        str = Rudy::Utils.strand
        group = @ec2group.create(test_name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object (#{group.class.to_s})"
        assert_equal group.name, test_name, "Group name not set"
        assert_equal group.description, "Security Group #{test_name}", "Group description not 'Security Group #{test_name}'"
        assert @ec2group.exists?(test_name), "Group #{test_name} doesn't exist"
      end
      
      should "(02) create group with name and description" do
        test_name ||= 'test-' << Rudy::Utils.strand
        str = Rudy::Utils.strand
        desc = "Description for #{test_name}"
        group = @ec2group.create(test_name, desc)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert_equal group.name, test_name, "Group name not set"
        assert_equal group.description, desc, "Group description not set"
        assert @ec2group.exists?(test_name), "Group #{test_name} doesn't exist"
      end
      
      should "(10) list available groups" do
        group_list = @ec2group.list
        assert group_list.is_a?(Array), "Group list is not an Array"

        group_list_hash = @ec2group.list_as_hash
        assert group_list_hash.is_a?(Hash), "Group list is not an Hash"

        group_list.each do |group|
          assert group.is_a?(Rudy::AWS::EC2::Group), "Not a group"
        end
      end
      
      should "(20) authorize/revoke group rules for address" do
        external_ip_address = Rudy::Utils::external_ip_address
        external_ip_address ||= '192.168.0.1/32'

        test_name ||= 'test-' << Rudy::Utils.strand

        group = @ec2group.create(test_name)
        protocols = ['tcp', 'udp']
        addresses = [external_ip_address]
        ports = [[3100,3150],[3200,3250]]
        
        ret = @ec2group.authorize(test_name, addresses, ports, protocols)
        assert ret, "Authorize did not return true"
        
        group = @ec2group.get(test_name)
        
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a group (#{group})"
        assert group.addresses.is_a?(Hash), "Addresses is not a hash (#{group.addresses})"
        
        group.addresses.each_pair do |address,rules|
          assert rules.is_a?(Array), "Not an Array"
          assert_equal 7, rules.size, "Not 7 rules"
          puts "TODO: Check port ranges"
        end
        
        ret = @ec2group.revoke(test_name, addresses, ports, protocols)
        assert ret, "Revoke did not return true"
        sleep 1 # Wait for eventual consistency
        group = @ec2group.get(test_name)
        assert group.addresses.is_a?(Hash), "Addresses is not a hash"
        assert group.addresses.empty?, "Some addresses not revoked #{group.addresses.to_s}"
      end
      
      
      should "(21) authorize/revoke group permissions for account/group" do
        test_name ||= 'test-' << Rudy::Utils.strand
        group = @ec2group.create(test_name)
        should_have = "#{@accountnum}:#{test_name}"
        
        ret = @ec2group.authorize_group(test_name, test_name, @accountnum)
        assert ret, "Authorize failed (#{should_have})"
        group = @ec2group.get(test_name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert_equal should_have, group.groups.keys.first, "Authorized group is not #{should_have}"
        # TODO: Check port ranges
        
        ret = @ec2group.revoke_group(test_name, test_name, @accountnum)
        assert ret, "Revoke failed (#{should_have})"
        group = @ec2group.get(test_name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert !group.groups.has_key?(should_have), "Still authorized for #{should_have}"
      end
      
      
      should "(50) destroy groups" do
        group_list = get_groups
        assert !group_list.empty?, "No groups"
        group_list.each_pair do |gname,group|
          assert @ec2group.destroy(group.name), "Not destroyed (#{group.name})"
        end
      end
      

    end
    
      
  end
end