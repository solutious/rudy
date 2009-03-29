require File.join(File.dirname(__FILE__), 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class EC2 < Test::Unit::TestCase
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@ec2 = @@rmach.ec2
    
    def setup
      #stop_test @@rmach.is_a?(Rudy::Machines), "We don't have an instance of Rudy::Machines (#{@@rmach})"
      #stop_test @@ec2.is_a?(Rudy::AWS::EC2::Instances), "We don't have an instance of Rudy::AWS::EC2"
      #stop_test @@rmach.config && @@rmach.config.awsinfo && @@rmach.config.awsinfo.account, "No account number"
    end
    
    
    context "(10) EC2 KeyPairs" do
      should "(01) create keypair" do
        name = 'test-' << Rudy::Utils.strand
        keypair = @@ec2.keypairs.create(name)
        assert keypair.is_a?(Rudy::AWS::EC2::KeyPair), "Not a KeyPair"
        assert !keypair.name.empty?, "No name"
        assert !keypair.fingerprint.empty?, "No fingerprint"
        assert !keypair.private_key.empty?, "No private key"
      end
      
      should "(02) list keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
      end
      
      should "(03) destroy keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
        keypairs.each do |kp|
          @@ec2.keypairs.destroy(kp.name)
        end
      end
    end
    
    context "(20) EC2 Groups" do
      def setup 
        @external_ip_address ||= Rudy::Utils::external_ip_address
        @external_ip_address ||= '192.168.0.1/32'
      end
      
      should "(00) not be existing groups" do
        group_list = get_groups
        stop_test !group_list.empty?, "Destroy the existing groups (except \"default\")"
      end
      
      should "(01) create group with name" do
        group_list = get_groups
        
        str = Rudy::Utils.strand
        name = "test-name-#{str}"
        group = @@ec2.groups.create(name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert_equal group.name, name, "Group name not set"
        assert_equal group.description, "Group #{name}", "Group description not 'Group #{name}'"
      end
      
      should "(02) create group with name and description" do
        group_list = get_groups
        
        str = Rudy::Utils.strand
        name = "test-name-#{str}"
        desc = "test-desc-#{str}"
        group = @@ec2.groups.create(name, desc)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert_equal group.name, name, "Group name not set"
        assert_equal group.description, desc, "Group description not set"
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
      
      should "(20) authorize/revoke group permissions for address" do
        name = "test-" << Rudy::Utils.strand
        group = @@ec2.groups.create(name)
        protocols = ['tcp', 'udp']
        addresses = [@external_ip_address]
        ports = [[3100,3150],[3200,3250]]
        should_have = [] # The list of address keys we're expecting in Groups#addresses
        protocols.each do |protocol|
          addresses.each do |address|
            ports.each do |port|
              should_have << "#{address}/#{protocol}"
              ret = @@ec2.groups.authorize(name, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
              assert ret, "Did not authorize: #{port[0]}:#{port[1]} (#{protocol}) for #{address}"
            end
          end
        end
        group = @@ec2.groups.get(name)
        assert group.addresses.is_a?(Hash), "Addresses is not a hash"
        address_diff = group.addresses.keys - should_have
        assert address_diff.empty?, "Some addresses not created (#{address_diff.join(', ')})"
        group.addresses.each_pair do |address,perms|
          assert perms.is_a?(Array), "Not an Array"
          assert_equal 2, perms.size, "Not 2 perms"
          # TODO: Check port ranges
        end
        
        protocols.each do |protocol|
          addresses.each do |address|
            ports.each do |port|
              should_have << "#{address}/#{protocol}"
              ret = @@ec2.groups.revoke(name, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
              assert ret, "Did not revoke: #{port[0]}:#{port[1]} (#{protocol}) for #{address}"
            end
          end
        end
        
        group = @@ec2.groups.get(name)
        assert group.addresses.is_a?(Hash), "Addresses is not a hash"
        assert group.addresses.empty?, "Some addresses not revoked #{group.addresses.to_s}"
      end
      
      
      should "(21) authorize/revoke group permissions for account/group" do
        name = "test-" << Rudy::Utils.strand
        group = @@ec2.groups.create(name)
        should_have = "#{@@rmach.config.awsinfo.account}:#{name}"
        
        ret = @@ec2.groups.authorize_group(name, @@rmach.config.awsinfo.account, name)
        assert ret, "Authorize failed (#{should_have})"
        group = @@ec2.groups.get(name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert_equal should_have, group.groups.keys.first, "Authorized group is not #{should_have}"
        # TODO: Check port ranges
        
        ret = @@ec2.groups.revoke_group(name, @@rmach.config.awsinfo.account, name)
        assert ret, "Revoke failed (#{should_have})"
        group = @@ec2.groups.get(name)
        assert group.is_a?(Rudy::AWS::EC2::Group), "Not a Group object"
        assert group.groups.is_a?(Hash), "Groups is not a Hash (#{group.groups.class})"
        assert !group.groups.has_key?(should_have), "Still authorized for #{should_have}"
      end
      
      
      should "(50) destroy groups" do
        group_list = get_groups
        assert !group_list.empty?, "No groups"
        group_list.each_pair do |name,group|
          assert @@ec2.groups.destroy(group.name), "Not destroyed (#{group.name})"
        end
      end
      
      def get_groups
        group_list = @@ec2.groups.list_as_hash
        # "default" cannot be deleted so we exempt it
        group_list.reject { |name,group| name == "default" }
      end
    end
    
    context "(30) EC2 Addresses" do
      should "(00) not be existing addresses" do
        #p @@ec2.addresses.list
        stop_test @@ec2.addresses.any?, "Destroy the existing addresses"
      end
      
      should "(01) create address" do
        address = @@ec2.addresses.create
        assert address.is_a?(Rudy::AWS::EC2::Address), "Did not create"
        assert address.ipaddress.size > 0, "Address length is 0"
      end
      
      should "(02) list available addresses" do
        assert @@ec2.addresses.any?, "No addresses"
        assert @@ec2.addresses.list_as_hash.is_a?(Hash), "Not a Hash"
        assert @@ec2.addresses.list.is_a?(Array), "Not an Array"
        assert_equal 1, @@ec2.addresses.list.size, "More than one address"
      end
      
      should "(03) destroy address" do
        assert @@ec2.addresses.any?, "No addresses"
        @@ec2.addresses.list.each do |address|
          assert @@ec2.addresses.destroy(address), "Did not destroy"
        end
      end
    end
    
    context "(50) EC2 Instances" do
      
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