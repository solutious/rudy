
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
      
      def attach(inst_id, vol_id, device)
        @aws.attach_volume(:volume_id => vol_id, :instance_id => inst_id, :device => device)
      end
      
      def detach(vol_id)
        @aws.detach_volume(:volume_id => vol_id)
      end
      
      
      def list(vol_id=[])
        opts = { 
          :volume_id => vol_id ? [vol_id].flatten : [] 
        }
        begin
          list = @aws.describe_volumes(opts) || {}
        # NOTE: The InternalError is returned for non-existent volume IDs. 
        # It's probably a bug so we're ignoring it -- Dave. 
        rescue ::EC2::InternalError => ex 
          list = {}
        end
        return [] unless list['volumeSet'].is_a?(Hash)
        volumes = list['volumeSet']['item'].collect do |vol|
          Volumes.from_hash(vol)
        end
        volumes
      end
      
      # * +size+ the number of GB
      def create(zone, size, snapshot=nil)
        opts = {
          :availability_zone => zone,
          :size => (size || 1).to_s
        }
        
        opts[:snapshot] = snapshot if snapshot
        
        # "status"=>"creating", 
        # "size"=>"1", 
        # "snapshotId"=>nil, 
        # "requestId"=>"d42ff744-48b5-4f47-a3f0-7aba57a13eb9", 
        # "availabilityZone"=>"us-east-1b", 
        # "createTime"=>"2009-03-17T20:10:48.000Z", 
        # "volumeId"=>"vol-48826421"
        vol = @aws.create_volume(opts) || {}
        reqid = vol['requestId']
        Volumes.from_hash(vol) || nil
      end
      
      def Volumes.from_hash(h)
        # --- 
        # volumeSet: 
        #   item: 
        #   - status: available
        #     size: "1"
        #     snapshotId: 
        #     availabilityZone: us-east-1b
        #     attachmentSet: 
        #     createTime: "2009-03-17T20:10:48.000Z"
        #     volumeId: vol-48826421
        #     attachmentSet: 
        #       item: 
        #       - attachTime: "2009-03-17T21:49:54.000Z"
        #         status: attached
        #         device: /dev/sdh
        #         instanceId: i-956af3fc
        #         volumeId: vol-48826421
        #     
        # requestId: 8fc30e5b-a9c3-4fe0-a979-0f71e639a7c7
        vol = Rudy::AWS::EC2::Volume.new
        vol.status = h['status']
        vol.size = h['size']
        vol.snapshot = h['snapshotId']
        vol.zone = h['availabilityZone']
        vol.awsid = h['volumeId']
        vol.create_time = h['createTime']
        if h['attachmentSet'].is_a?(Hash)
          item = h['attachmentSet']['item'].first
          vol.status = item['status']   # Overwrite "available status". Possibly a bad idea. 
          vol.device = item['device']
          vol.attach_time = item['attachTime']
          vol.instid = item['instanceId']
        end
        vol
      end
      
      def destroy(vol_id)
        @aws.delete_volume(:volume_id => vol_id)
      end
      
      def exists?(vol_id)
        !list(vol_id).first.nil?
      end
      
      def get(vol_id)
        list(vol_id).first || nil
      end
      
      def deleting?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && vol.status == "deleting")
      end
      
      def available?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && vol.status == "available")
      end
      
      def attached?(vol_id)
        return false unless vol_id
        vol = get(vol_id)
        (vol && (vol.status == "in-use" || vol.status == "attached"))
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
          return true if v.device == device
        end
        false
      end
      
      def volumes(id)
        list = Rudy::AWS::EC2::Volumes.new(@aws).list || []
        list.select { |v| v.status != "deleting" && v.instid === id }
      end
      
      def device_volume(id, device)
        volumes(id).select { |v| v.device === device }
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
      
      # Returns:
      # ?
      def list
        @aws.describe_addresses || []
      end
      
      
      # Associate an elastic IP to an instance
      def associate(inst_id, address)
        opts ={
          :instance_id => inst_id || raise("No instance ID"),
          :public_ip => address || raise("No public IP adress")
        }
        @aws.associate_address(opts)
      end
      
      # TODO: Fix since with change to amazon-ec2
      def valid?(address)
        list.each do |a|
          return true if a[:public_ip] == address
        end
        false
      end
      
      # TODO: Fix since with change to amazon-ec2
      def associated?(address)
        list.each do |a|
          return true if a[:public_ip] == address && a[:instance_id]
        end
        false
      end
    end
  end
  
end