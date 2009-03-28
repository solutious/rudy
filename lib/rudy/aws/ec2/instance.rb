


module Rudy::AWS
  class EC2::Instance < Storable
    field :aki
    field :ari
    field :launch_index => Time
    field :launch_time
    field :keyname
    field :instance_type
    field :ami
    field :dns_name_private
    field :dns_name_public
    field :awsid
    field :state
    field :zone
    field :reason
    field :groups => Array
    
    def groups
      @groups || []
    end
    
        
    def to_s
      lines = []
      field_names.each do |key|
        next unless self.respond_to?(key)
        val = self.send(key)
        lines << sprintf(" %22s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      lines.join($/)
    end
    
  end
  
  
  class EC2::Instances
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
    def create(ami, group='default', keypair_name=nil, user_data=nil, zone=nil)
      opts = {
        :image_id => ami,
        :min_count => 1,
        :max_count => 1,
        :key_name => keypair_name,
        :group_id => [group].flatten,
        :user_data => user_data,
        :availability_zone => zone || DEFAULT_ZONE, 
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
    
    # * +state+ is an optional instance state. If specified, must be one of: running, pending, terminated.
    # * +inst_ids+ is an Array of instance IDs.
    # Returns an Array of Rudy::AWS::EC2::Instance objects. 
    def list(state=nil, inst_id=[])
      list_as_hash(state=nil, inst_id=[]).values
    end
    
    # * +state+ is an optional instance state. If specified, must be one of: running, pending, terminated.
    # * +inst_ids+ is an Array of instance IDs.
    # Returns a Hash of Rudy::AWS::EC2::Instance objects. The key is the instance ID. 
    def list_as_hash(state=nil, inst_id=[])
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
      instances = list_as_hash(state) || {}
      instances.reject { |id,inst| !inst.groups.member?(group) }    
    end
    
    # +inst_id+ is an instance ID
    # Returns an Instance object
    def get(inst_id)
      inst = list(nil, inst_id)
      inst.first if inst
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
    def self.from_hash(h)
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

end