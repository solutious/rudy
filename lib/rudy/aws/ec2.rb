
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
        @aws.terminate_instances(:instance_id => list.flatten)
      end
      
      def restart(*list)
        @aws.reboot_instances(:instance_id => list.flatten)
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
        p list
        exit
        list.select { |v| v[:aws_status] != "deleting" && v[:aws_instance_id] === id }
      end
      
      def device_volume(id, device)
        volumes.select { |v| v[:aws_device] === device }
      end
      
      
      # Return an Array of Instances objects
      def create(ami, group, keypair_name, user_data, zone)
        opts = {
          :image_id => ami,
          :min_count => 1,
          :max_count => 1,
          :key_name => keypair_name,
          :group_id => [group].flatten,
          :user_data => user_data,
          :availability_zone => zone, 
          :addressing_type => 'public',
          :instance_type => 'm1.small',
          :kernel_id => nil
        }
        
        # reservationId: r-f393149a
        # groupSet: 
        #   item: 
        #   - groupId: default
        # requestId: a4de33de-6da1-4f43-a3f5-f987f5f1f1cf
        # instancesSet: 
        #   item:
        #     ... # see from_hash
        ilist = @aws.run_instances(opts) || {}
        reqid = ilist['requestId']
        resid = ilist['reservationId']
        raise "The request failed to return instance data" unless ilist['instancesSet'].is_a?(Hash)
        instances = ilist['instancesSet']['item'].collect do |inst|
          Instances.from_hash(inst)
        end
        instances
      end
      
      # * +inst_ids+ is an Array of instance IDs.
      # * +state+ is an optional instance state. If specified, must be one of: running, pending, terminated.
      # Returns a hash of Rudy::AWS::EC2::Instance objects. The key is the instance ID. 
      def list(inst_ids, state=nil)
        state &&= state.to_sym
        inst_ids &&= [inst_ids].flatten
        inst_ids ||= []
        raise "Unknown state given: #{state}" if state && ![:running, :pending, :terminated].member?(state)
        
        # requestId: c16878ac-28e4-4859-9878-ef93af45789c
        # reservationSet: 
        #   item: 
        #   - reservationId: r-e493148d
        #     groupSet: 
        #       item: 
        #       - groupId: default
        #     instancesSet: 
        #       item: 
        #
        begin
          ilist = @aws.describe_instances(:instance_id => inst_ids) || {}
          reqid = ilist['requestId']
          resids = []
        rescue ::EC2::InvalidInstanceIDMalformed => ex
          ilist = {}
        end
        
        return nil unless ilist['reservationSet'].is_a?(Hash)  # No instances 
        
        instances = {}
        # AWS Returns instances grouped by reservation
        ilist['reservationSet']['item'].each do |res|      
          resids << res['reservationId']
          groups = res['groupSet']['item'].collect { |g| g['groupId'] }
          # And each reservation can have 1 or more instances
          next unless res['instancesSet'].is_a?(Hash)
          res['instancesSet']['item'].each do |props|
            inst = Instances.from_hash(props)
            inst.groups = groups
            next if state && inst.state != state.to_s
            instances[inst.awsid] = inst
          end
        end
        instances
      end
      
      # +group+ is a security group name. 
      # +state+ is an optional instance state. Must be one of: running, pending, terminated.
      # Returns a hash of Rudy::AWS::EC2::Instance objects. The key is the instance ID.
      def list_by_group(group, state=nil)
        instances = list([], state) || {}
        instances.reject { |id,inst| !inst.groups.member?(group) }    
      end
      
      # +inst_id+ is an instance ID
      # Returns an Instance object
      def get(inst_id)
        inst = list(inst_id)
        inst.values.first if inst
      end
      
      def running?(inst_id)
        inst = get(inst_id)
        (!inst.nil? && inst.state == "running")
      end
      
      def pending?(inst_id)
        inst = get(inst_id)
        (!inst.nil? && inst.state == "pending")
      end
      
      def terminated?(inst_id)
        inst = get(inst_id)
        (!inst.nil? && inst.state == "terminated") # also, shutting-down
      end
      
      #
      # +h+ is a hash of instance properties in the format returned
      # by EC2::Base#describe_instances:
      #   
      #       kernelId: aki-9b00e5f2
      #       amiLaunchIndex: "0"
      #       keyName: solutious-default
      #       launchTime: "2009-03-14T12:48:15.000Z"
      #       instanceType: m1.small
      #       imageId: ami-0734d36e
      #       privateDnsName: 
      #       reason: 
      #       placement: 
      #         availabilityZone: us-east-1b
      #       dnsName: 
      #       instanceId: i-cdaa34a4
      #       instanceState: 
      #         name: pending
      #         code: "0"
      #
      # Returns an Instance object.
      def Instances.from_hash(h)
        # Was:
        # :aws_image_id, :aws_reason, :aws_state_code, :aws_owner, :aws_instance_id, :aws_reservation_id 
        # :aws_state, :dns_name, :ssh_key_name, :aws_groups, :private_dns_name, :aws_instance_type, 
        # :aws_launch_time, :aws_availability_zone :aws_kernel_id, :aws_ramdisk_id
        inst = Rudy::AWS::EC2::Instance.new
        inst.aki = h['kernelId']
        inst.ami = h['imageId']
        inst.launch_time = h['launchTime']
        inst.keyname = h['keyName']
        inst.launch_index = h['amiLaunchIndex']
        inst.instance_type = h['instanceType']
        inst.dns_name_private = h['privateDnsName']
        inst.dns_name_public = h['dnsName']
        inst.reason = h['reason']
        inst.zone = h['placement']['availabilityZone']
        inst.awsid = h['instanceId']
        inst.state = h['instanceState']['name']
        inst
      end


    end
    
    class Groups
      include Rudy::AWS::ObjectBase
    
      
      # +list+ is a list of security group names to look for. If it's empty, all groups
      # associated to the account will be returned.
      # Returns an Array of Rudy::AWS::EC2::Group objects
      def list(list=[])
        glist = @aws.describe_security_groups(:group_name => list) || {}
        return unless glist['securityGroupInfo'].is_a?(Hash)
        groups = glist['securityGroupInfo']['item'].collect do |oldg| 
          Groups.from_hash(oldg)
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
        @aws.delete_security_group(:group_name => name)
      end
      
      # +name+ a string
      def get(name)
        (list([name]) || []).first
      end
      
      # +group+ a Rudy::AWS::EC2::Group object
      #def save(group)
      #  
      #end
      
      def modify(meth, name, from_port, to_port, protocol='tcp', ipa='0.0.0.0/0', gname=nil, gowner=nil)
        opts = {
          :group_name => name,
          :ip_protocol => protocol,
          :from_port => from_port,
          :to_port => to_port,
          :cidr_ip => ipa,
          :source_security_group_name => gname,
          :source_security_group_owner_id => gowner
        }
        @aws.send("#{meth}_security_group_ingress", opts)
      end
      private :modify
      
      # Authorize a port/protocol for a specific IP address
      def authorize(*args)
        modify(:authorize, *args)
      end
      alias :authorise :authorize
      
      # Revoke a port/protocol for a specific IP address
      # Takes the same arguments as authorize
      def revoke(*args)
        modify(:revoke, *args)
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
      def Groups.from_hash(oldg)
        newg = Rudy::AWS::EC2::Group.new
        newg.name = oldg['groupName']
        newg.description = oldg['groupDescription']
        newg.owner_id = oldg['ownerId']
        return newg unless oldg['ipPermissions'].is_a?(Hash)
        newg.permissions = oldg['ipPermissions']['item'].collect do |oldp|
          newp = Rudy::AWS::EC2::Group::Permissions.new
          newp.ports = Range.new(oldp['fromPort'], oldp['toPort'])
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