
module Rudy::Test

  class Case_25_EC2
    
    def get_groups
      # Ruby 1.8 throws an undefined method error when this is at the 
      # bottom of the class
      group_list = @@ec2.groups.list_as_hash
      # "default" cannot be deleted so we exempt it
      group_list.reject { |gname,group| gname == "default" }
    end
    
    
    context "#{name}_20 Groups" do
      
      should "(00) not be existing groups" do
        group_list = get_groups
        stop_test !group_list.empty?, "Destroy the existing groups (except \"default\")"
      end
      
      should "(01) create group with name" do
        group_list = get_groups
        
        str = Rudy::Utils.strand
        gname = "test-name-#{str}"
        group = @@ec2.groups.create(gname)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert_equal group.name, gname, "Group name not set"
        assert_equal group.description, "Group #{gname}", "Group description not 'Group #{gname}'"
        assert @@ec2.groups.exists?(gname), "Group #{gname} doesn't exist"
      end
      
      should "(02) create group with name and description" do
        group_list = get_groups
        
        str = Rudy::Utils.strand
        gname = "test-name-#{str}"
        desc = "test-desc-#{str}"
        group = @@ec2.groups.create(gname, desc)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert_equal group.name, gname, "Group name not set"
        assert_equal group.description, desc, "Group description not set"
        assert @@ec2.groups.exists?(gname), "Group #{gname} doesn't exist"
      end
      
      should "(10) list available groups" do
        group_list = @@ec2.groups.list
        assert group_list.is_a?(Array), "Group list is not an Array"

        group_list_hash = @@ec2.groups.list_as_hash
        assert group_list_hash.is_a?(Hash), "Group list is not an Hash"

        group_list.each do |group|
          assert group.is_a?(Rudy::AWS::EC2::Group), "Not a group"
        end
      end
      
      should "(20) authorize/revoke group rules for address" do
        external_ip_address = Rudy::Utils::external_ip_address
        external_ip_address ||= '192.168.0.1/32'
        
        gname = "test-" << Rudy::Utils.strand
        group = @@ec2.groups.create(gname)
        protocols = ['tcp', 'udp']
        addresses = [external_ip_address]
        ports = [[3100,3150],[3200,3250]]
        should_have = [] # The list of address keys we're expecting in Groups#addresses
        protocols.each do |protocol|
          addresses.each do |address|
            ports.each do |port|
              should_have << "#{address}/#{protocol}"
              ret = @@ec2.groups.authorize(gname, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
              assert ret, "Did not authorize: #{port[0]}:#{port[1]} (#{protocol}) for #{address}"
            end
          end
        end
        group = @@ec2.groups.get(gname)
        assert group.addresses.is_a?(Hash), "Addresses is not a hash"
        address_diff = group.addresses.keys - should_have
        assert address_diff.empty?, "Some addresses not created (#{address_diff.join(', ')})"
        group.addresses.each_pair do |address,rules|
          assert rules.is_a?(Array), "Not an Array"
          assert_equal 2, rules.size, "Not 2 rules"
          # TODO: Check port ranges
        end
        
        protocols.each do |protocol|
          addresses.each do |address|
            ports.each do |port|
              should_have << "#{address}/#{protocol}"
              ret = @@ec2.groups.revoke(gname, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
              assert ret, "Did not revoke: #{port[0]}:#{port[1]} (#{protocol}) for #{address}"
            end
          end
        end
        
        group = @@ec2.groups.get(gname)
        assert group.addresses.is_a?(Hash), "Addresses is not a hash"
        assert group.addresses.empty?, "Some addresses not revoked #{group.addresses.to_s}"
      end
      
      
      should "(21) authorize/revoke group permissions for account/group" do
        gname = "test-" << Rudy::Utils.strand
        group = @@ec2.groups.create(gname)
        should_have = "#{@@rmach.config.awsinfo.account}:#{gname}"
        
        ret = @@ec2.groups.authorize_group(gname, gname, @@rmach.config.awsinfo.account)
        assert ret, "Authorize failed (#{should_have})"
        group = @@ec2.groups.get(gname)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert_equal should_have, group.groups.keys.first, "Authorized group is not #{should_have}"
        # TODO: Check port ranges
        
        ret = @@ec2.groups.revoke_group(gname, gname, @@rmach.config.awsinfo.account)
        assert ret, "Revoke failed (#{should_have})"
        group = @@ec2.groups.get(gname)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert !group.groups.has_key?(should_have), "Still authorized for #{should_have}"
      end
      
      
      should "(50) destroy groups" do
        group_list = get_groups
        assert !group_list.empty?, "No groups"
        group_list.each_pair do |gname,group|
          assert @@ec2.groups.destroy(group.name), "Not destroyed (#{group.name})"
        end
      end
      

    end
    
      
  end
end