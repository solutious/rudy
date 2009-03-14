
module Rudy::AWS
  
  class EC2
    class UserData
      
    end
    
    class Images
      include Rudy::AWS::ObjectBase
      
      # Returns an array of hashes:
      # {:aws_architecture=>"i386", :aws_owner=>"105148267242", :aws_id=>"ami-6fe40dd5", 
      #  :aws_image_type=>"machine", :aws_location=>"bucket-name/your-image.manifest.xml", 
      #  :aws_kernel_id=>"aki-a71cf9ce", :aws_state=>"available", :aws_ramdisk_id=>"ari-a51cf9cc", 
      #  :aws_is_public=>false}
      def list
        @aws.describe_images_by_owner('self') || []
      end
      
      # +id+ AMI ID to deregister (ami-XXXXXXX)
      # Returns true when successful. Otherwise throws an exception.
      def deregister(id)
        @aws.deregister_image(id)
      end
      
      # +path+ the S3 path to the manifest (bucket/file.manifest.xml)
      # Returns the AMI ID when successful, otherwise throws an exception.
      def register(path)
        @aws.register_image(path)
      end
    end
    class Snapshots
      include Rudy::AWS::ObjectBase
      
      def list
        @aws.describe_snapshots || []
      end
      
      def create(vol_id)
        @aws.create_snapshot(vol_id)
      end
      
      def destroy(snap_id)
        @aws.delete_snapshot(snap_id)
      end
      
      def exists?(id)
        list.each do |v|
          return true if v[:aws_id] === id
        end
        false
      end
      
    end
    
    class Volumes
      include Rudy::AWS::ObjectBase
      
      # [{:aws_device=>"/dev/sdr",
      # :aws_attachment_status=>"attached",
      # :snapshot_id=>nil,
      # :aws_id=>"vol-6811f601",
      # :aws_attached_at=>Wed Mar 11 07:06:44 UTC 2009,
      # :aws_status=>"in-use",
      # :aws_instance_id=>"i-0b2ab662",
      # :aws_created_at=>Tue Mar 10 18:55:18 UTC 2009,
      # :zone=>"us-east-1b",
      # :aws_size=>10}]
      def list
        list = @aws.describe_volumes() || []
        list.select { |v| v[:aws_status] != "deleting" }
      end
      
      def attach(inst_id, vol_id, device)
        @aws.attach_volume(vol_id, inst_id, device)
      end
      
      def detach(vol_id)
        @aws.detach_volume(vol_id)
      end
      
      def create(zone, size, snapshot=nil)
        @aws.create_volume(snapshot, size, zone)
      end
      
      def destroy(vol_id)
        @aws.delete_volume(vol_id)
      end
      
      def exists?(id)
        list.each do |v|
          return true if v[:aws_id] === id
        end
        false
      end
      
      def get(vol_id)
        list = @aws.describe_volumes(vol_id) || []
        list.first
      end
      
      def deleting?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && vol[:aws_status] == "deleting")
      end
      
      def available?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && vol[:aws_status] == "available")
      end
      
      def attached?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && vol[:aws_status] == "in-use")
      end
        
    end
    
    class Instances
      include Rudy::AWS::ObjectBase
      
      def destroy(*list)
        begin
          @aws.terminate_instances(list.flatten)
        #rescue RightAws::AwsError => ex
        #  raise UnknownInstance.new
        end
      end
      
      def restart(*list)
        @aws.reboot_instances(list.flatten)
      end
      
      def attached_volume?(id, device)
        list = volumes(id)
        list.each do |v|
          return true if v[:aws_device] == device
        end
        false
      end
      
      def volumes(id)
        list = @aws.describe_volumes() || []
        list.select { |v| v[:aws_status] != "deleting" && v[:aws_instance_id] === id }
      end
      
      def device_volume(id, device)
        volumes.select { |v| v[:aws_device] === device }
      end
      
      def create(ami, group, keypair_name, user_data, zone)
        @aws.run_instances(ami, 1, 1, [group], keypair_name, user_data, 'public', nil, nil, nil, zone)
      end
      
      # Creates a list of running instance IDs which are in a security group
      # that matches +filter+. 
      # Returns a hash. The keys are instance IDs and the values are a hash
      # of attributes associated to that instance. 
      # {:aws_state_code=>"16",
      # :private_dns_name=>"domU-12-31-38-00-51-F1.compute-1.internal",
      # :aws_instance_type=>"m1.small",
      # :aws_reason=>"",
      # :ami_launch_index=>"0",
      # :aws_owner=>"207436219441",
      # :aws_launch_time=>"2009-03-11T06:55:00.000Z",
      # :aws_kernel_id=>"aki-a71cf9ce",
      # :ssh_key_name=>"rilli-sexytime",
      # :aws_reservation_id=>"r-66f5710f",
      # :aws_state=>"running",
      # :aws_ramdisk_id=>"ari-a51cf9cc",
      # :aws_instance_id=>"i-0b2ab662",
      # :aws_groups=>["rudydev-app"],
      # :aws_availability_zone=>"us-east-1b",
      # :aws_image_id=>"ami-daca2db3",
      # :aws_product_codes=>[],
      # :dns_name=>"ec2-67-202-9-30.compute-1.amazonaws.com"}
      def list(filter='.')
        filter = filter.to_s.downcase.tr('_|-', '.') # treat dashes, underscores as one
        # Returns an array of hashes with the following keys:
        # :aws_image_id, :aws_reason, :aws_state_code, :aws_owner, :aws_instance_id, :aws_reservation_id 
        # :aws_state, :dns_name, :ssh_key_name, :aws_groups, :private_dns_name, :aws_instance_type, 
        # :aws_launch_time, :aws_availability_zone :aws_kernel_id, :aws_ramdisk_id
        instances = @aws.describe_instances || []
        running_instances = {}
        instances.each do |inst|
          if inst[:aws_state] != "terminated" && (inst[:aws_groups].to_s =~ /#{filter}/)
            running_instances[inst[:aws_instance_id]] = inst
          end
        end
        running_instances
      end
      
      def get(inst_id)
        # This is ridiculous. Send inst_id to describe volumes
        instance = {}
        list.each_pair do |id, hash|
          next unless inst_id == id
          instance = hash
        end
        instance
      end
      
      def running?(inst_id)
        inst = get(inst_id)
        (inst && inst[:aws_state] == "running")
      end
      
      def pending?(inst_id)
        inst = get(inst_id)
        (inst && inst[:aws_state] == "pending")
      end
    end
    
    class Groups
      include Rudy::AWS::ObjectBase
    
      
      # +list+ is a list of security group names to look for. If it's empty, all groups
      # associated to the account will be returned.
      # Returns an Array of Rudy::AWS::EC2::Group objects
      def list(list=[])
        glist = @aws.describe_security_groups(:group_name => list) || {}
        groups = glist['securityGroupInfo']['item'].collect do |oldg| 
          Groups.hash_to_obj(oldg)
        end
        groups
      end
      
      # Create a new EC2 security group
      # Returns true/false whether successful
      def create(name, desc=nil)
        @aws.create_security_group(:group_name => name, :group_description => desc || "Group #{name}")
      end
      
      # Delete an EC2 security group
      # Returns true/false whether successful
      def destroy(name)
        @aws.delete_security_group(name)
      end
      
      # +name+ a string
      def get(name)
        (list([name]) || []).first
      end
      
      # +group+ a Rudy::AWS::EC2::Group object
      #def save(group)
      #  
      #end
      
      # Authorize a port/protocol for a specific IP address
      def authorize(name, from_port, to_port, protocol='tcp', ipa='0.0.0.0/0')
        opts = {
          :group_name => name,
          :ip_protocol => protocol,
          :from_port => from_port,
          :to_port => to_port,
          :cidr_ip => ipa
        }
        @aws.authorize_security_group_ingress(opts)
      end
      alias :authorise :authorize
      
      # Revoke a port/protocol for a specific IP address
      def revoke(name, from_port, to_port, protocol='tcp', ipa='0.0.0.0/0')
        opts = {
          :group_name => name,
          :ip_protocol => protocol,
          :from_port => from_port,
          :to_port => to_port,
          :cidr_ip => ipa
        }
        @aws.revoke_security_group_ingress(opts)
      end
        
      
      # Does the security group +name+ exist?
      def exists?(name)
        begin
          g = list([name.to_s])
        rescue
          return false
        end
        
        !g.empty?
      end
      
      
      
      
      # +oldg+ is an EC2::Base Security Group Hash. This is the format
      # returned by EC2::Base#describe_security_groups
      #
      #      groupName: stage-app
      #      groupDescription: 
      #      ownerId: "207436219441"
      #      ipPermissions: 
      #        item: 
      #        - ipRanges: 
      #            item: 
      #            - cidrIp: 216.19.182.83/32
      #            - cidrIp: 24.5.71.201/32
      #            - cidrIp: 75.157.176.202/32
      #            - cidrIp: 84.28.52.172/32
      #            - cidrIp: 87.212.145.201/32
      #            - cidrIp: 96.49.129.178/32
      #          groups: 
      #            item: 
      #            - groupName: default
      #              userId: "207436219441"
      #            - groupName: stage-app
      #              userId: "207436219441"  
      #          fromPort: "22"
      #          toPort: "22"
      #          ipProtocol: tcp
      #
      # Returns a Rudy::AWS::EC2::Group object
      def Groups.hash_to_obj(oldg)
        newg = Rudy::AWS::EC2::Group.new
        newg.name = oldg['groupName']
        newg.description = oldg['groupDescription']
        newg.owner_id = oldg['ownerId']
        return newg unless oldg['ipPermissions'].is_a?(Hash)
        newg.permissions = oldg['ipPermissions']['item'].collect do |oldp|
          newp = Rudy::AWS::EC2::Group::Permissions.new
          newp.source = oldp['fromPort']
          newp.destination = oldp['toPort']
          newp.protocol = oldp['ipProtocol']
          if oldp['groups'].is_a?(Hash)
            newp.groups = oldp['groups']['item'].collect do |oldpg|
              [oldpg['userId'], oldpg['groupName']].join(':')   # account_num:name
            end
          end
          if oldp['ipRanges'].is_a?(Hash)
            newp.addresses = oldp['ipRanges']['item'].collect do |olda|
              olda['cidrIp']
            end
          end
          newp
        end
        newg
      end
      
      
    end
    
    class Addresses
      include Rudy::AWS::ObjectBase
      
      # Returns and array of hashes:
      # [{:instance_id=>"i-d630cbbf", :public_ip=>"75.101.1.140"},
      #  {:instance_id=>nil, :public_ip=>"75.101.1.141"}]
      def list
        @aws.describe_addresses || []
      end
      
      
      # Associate an elastic IP to an instance
      def associate(instance, address)
        @aws.associate_address(instance, address)
      end
      
      def valid?(address)
        list.each do |a|
          return true if a[:public_ip] == address
        end
        false
      end
      
      def associated?(address)
        list.each do |a|
          return true if a[:public_ip] == address && a[:instance_id]
        end
        false
      end
    end
  end
  
end