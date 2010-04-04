


module Rudy::AWS
  class EC2::Instance < Storable
    @@sformat = "   -> %10s; %10s; %12s; %10s; groups: %s"
    field :launch_index => Time
    field :groups => Array
    field :aki => String
    field :ari => String
    field :created => String
    field :keyname => String
    field :size => String
    field :ami => String
    field :dns_private => String
    field :dns_public => String
    field :awsid => String
    field :state => String
    field :zone => String
    field :reason => String
    
    def init
      @groups ||= []
    end
    
    def to_s(*args)
      groups = [@groups].flatten.compact.join(', ')
      [self.awsid.bright, self.state, self.dns_public, groups].join '; '
    end
    
    def running?; self.state && self.state == 'running'; end
    def pending?; self.state && self.state == 'pending'; end
    def terminated?; self.state && self.state == 'terminated'; end
    def degraded?; self.state && self.state == 'degraded'; end
    def shutting_down?; self.state && self.state == 'shutting-down'; end
      
  end
  
  
  module EC2
    module Instances
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
      
      unless defined?(KNOWN_STATES)
        KNOWN_STATES = [:running, :pending, :shutting_down, :terminated, :degraded].freeze 
      end
    
      # Return an Array of Instance objects. Note: These objects will not have
      # DNS data because they will still be in pending state. The DNS info becomes
      # available once the instance enters the running state.
      #
      # +opts+ supports the following parameters:
      #
      # * +:zone+
      # * +:ami+          
      # * +:group+        
      # * +:size+          
      # * +:keypair+
      # * +:private+ true or false (default)
      # * +:machine_data+
      # * +:min+ count
      # * +:max+ count
      #
      def create(opts={}, &each_inst)
        raise NoAMI unless opts[:ami]
        raise NoGroup unless opts[:group]
        
        opts = {
          :size => 'm1.small',
          :min => 1,
          :max => nil
        }.merge(opts)
        
        old_opts = {
          :image_id => opts[:ami].to_s,
          :min_count => opts[:min],
          :max_count => opts[:max] || opts[:min],
          :key_name => (opts[:keypair] || '').to_s,
          :security_group => [opts[:group]].flatten.compact,
          #:user_data => opts[:machine_data],  # Error: Invalid BASE64 encoding of user data ??
          :availability_zone => opts[:zone].to_s,
          :instance_type => opts[:size].to_s,
          :kernel_id => nil
        }
        
        response = Rudy::AWS::EC2.execute_request({}) { @@ec2.run_instances(old_opts) }
        return nil unless response['instancesSet'].is_a?(Hash)
        instances = response['instancesSet']['item'].collect do |inst|
          self.from_hash(inst)
        end
        instances.each { |inst| 
          each_inst.call(inst) 
        } if each_inst
        instances
      end
    
      def restart(inst_ids=[], &each_inst)
        instances = list(:running, inst_ids, &each_inst) || []
        raise NoRunningInstances if instances.empty?
        inst_ids = objects_to_instance_ids(inst_ids)
        response = Rudy::AWS::EC2.execute_request({}) {
          @@ec2.reboot_instances(:instance_id => inst_ids)
        }
        response['return'] == 'true'
      end
    
      def destroy(inst_ids=[], &each_inst)
        instances = list(:running, inst_ids, &each_inst) || [] 
        raise NoRunningInstances if instances.empty?
      
        inst_ids = objects_to_instance_ids(inst_ids)
            
        response = Rudy::AWS::EC2.execute_request({}) {
          @@ec2.terminate_instances(:instance_id => inst_ids)
        }
      
        #instancesSet: 
        #  item: 
        #  - instanceId: i-ebdcb882
        #    shutdownState: 
        #      code: "48"
        #      name: terminated
        #    previousState: 
        #      code: "48"
        #      name: terminated
      
        raise MalformedResponse unless response['instancesSet'].is_a?(Hash)
        instances_shutdown = []
        response['instancesSet']['item'].collect do |inst|
          next unless inst['shutdownState'].is_a?(Hash) && inst['shutdownState']['name'] == 'shutting-down'
          instances_shutdown << inst['instanceId']
        end
        success = instances_shutdown.size == inst_ids.size
        success
      end
    
      def restart_group(group, &each_inst)
        instances = list_group(group, :running, &each_inst) || []
        inst_ids = objects_to_instance_ids(instances)
        restart(inst_ids, :skip_check)
      end
    
      def destroy_group(group, &each_inst)
        instances = list_group(group, :running, &each_inst) || []
        inst_ids = objects_to_instance_ids(instances)
        destroy(inst_ids, :skip_check)
      end
    
      # * +state+ is an optional instance state. If specified, must be one of: running (default), pending, terminated.
      # * +inst_ids+ is an Array of instance IDs.
      # Returns an Array of Rudy::AWS::EC2::Instance objects. 
      def list(state=nil, inst_ids=[], &each_inst)
        instances = list_as_hash(state, inst_ids, &each_inst)
        instances &&= instances.values
        instances = nil if instances && instances.empty? # Don't return an empty hash
        instances
      end
    
      # * +group+ is a security group name.
      # * +state+ is an optional instance state. If specified, must be one of: running (default), pending, terminated.
      # * +inst_ids+ is an Array of instance IDs.
      def list_group(group=nil, state=nil, inst_ids=[], &each_inst)
        instances = list_group_as_hash(group, state, inst_ids, &each_inst)
        instances &&= instances.values
        instances = nil if instances && instances.empty? # Don't return an empty hash
        instances
      end
    
    
      # * +group+ is a security group name.
      # * +state+ is an optional instance state. If specified, must be one of: running (default), pending, terminated.
      # * +inst_ids+ is an Array of instance IDs.
      def list_group_as_hash(group=nil, state=nil, inst_ids=[], &each_inst)
        instances = list_as_hash(state, inst_ids)
        # Remove instances that are not in the specified group
        if instances
          instances = instances.reject { |id,inst| !inst.groups.member?(group) } if group
          instances.each_value { |inst| each_inst.call(inst) } if each_inst
        end
        instances = nil if instances && instances.empty? # Don't return an empty hash
        instances
      end
    
      # * +state+ is an optional instance state. If specified, must be 
      # one of: running (default), pending, terminated, any
      # * +inst_ids+ is an Array of instance IDs or Rudy::AWS::EC2::Instance objects.
      # Returns a Hash of Rudy::AWS::EC2::Instance objects. The key is the instance ID. 
      # * +each_inst+ a block to execute for every instance in the list.
      def list_as_hash(state=nil, inst_ids=[], &each_inst)
        state &&= state.to_sym
        state = nil if state == :any
        raise "Unknown state: #{state}" if state && !Instances.known_state?(state)
        state = :'shutting-down' if state == :shutting_down # EC2 uses a dash

        # If we got Instance objects, we want just the IDs.
        # This method always returns an Array.
        inst_ids = objects_to_instance_ids(inst_ids)
      
        response = Rudy::AWS::EC2.execute_request({}) {
          @@ec2.describe_instances(:instance_id => inst_ids)
        }
      
        # requestId: c16878ac-28e4-4859-9878-ef93af45789c
        # reservationSet: 
        #   item: 
        #   - reservationId: r-e493148d
        #     groupSet: 
        #       item: 
        #       - groupId: default
        #     instancesSet: 
        #       item:
        return nil unless response['reservationSet'].is_a?(Hash)  # No instances 
      
        resids = []
        instances = {}
        response['reservationSet']['item'].each do |res|      
          resids << res['reservationId']
          groups = res['groupSet']['item'].collect { |g| g['groupId'] }
          # And each reservation can have 1 or more instances
          next unless res['instancesSet'].is_a?(Hash)
          res['instancesSet']['item'].each do |props|
            inst = Instances.from_hash(props)
            next if state && inst.state != state.to_s
            inst.groups = groups
            #puts "STATE: #{inst.state} #{state}"
            instances[inst.awsid] = inst
          end
        end
        
        instances.each_value { |inst| each_inst.call(inst) } if each_inst
        
        instances = nil if instances.empty? # Don't return an empty hash
        instances
      end

      # System console output. 
      #
      # * +inst_id+ instance ID (String) or Instance object.
      #
      # NOTE: Amazon sends the console outputs as a Base64 encoded string.
      # This method DOES NOT decode in order to remain compliant with the 
      # data formats returned by Amazon. 
      #
      # You can decode it like this:
      #
      #      require 'base64'
      #      Base64.decode64(output)
      #
      def console(inst_id, &each_inst)
        inst_ids = objects_to_instance_ids([inst_id])
        response = Rudy::AWS::EC2.execute_request({}) { 
          @@ec2.get_console_output(:instance_id => inst_ids.first)
        }
        response['output']
      end
      
      def attached_volume?(id, device)
        list = volumes(id)
        list.each do |v|
          return true if v.device == device
        end
        false
      end
    
      def volumes(id)
        rvol = Rudy::AWS::EC2::Volumes.new
        rvol.ec2 = @ec2 
        rvol.list || []
        list.select { |v| v.attached? && v.instid === id }
      end
    
      def device_volume(id, device)
        volumes(id).select { |v| v.device === device }
      end
    
      # +inst_id+ is an instance ID
      # Returns an Instance object
      def get(inst_id)
        return nil if inst_id.nil?
        inst_id = inst_id.awsid if inst_id.is_a?(Rudy::AWS::EC2::Instance)
        inst = list(:any, inst_id) 
        inst &&= inst.first
        inst
      end
      
      def any?(state=:any, inst_ids=[])
        !list(state, inst_ids).nil?
      end
      
      def exists?(inst_ids)
        any?(:any, inst_ids)
      end
      
      def any_group?(group=nil, state=:any)
        ret = list_group(group, state)
        !ret.nil?
      end
        
      def running?(inst_ids)
        compare_instance_lists(list(:running, inst_ids), inst_ids)
      end
      def pending?(inst_ids)
        compare_instance_lists(list(:pending, inst_ids), inst_ids)
      end
      def terminated?(inst_ids)
        compare_instance_lists(list(:terminated, inst_ids), inst_ids)
      end
      def shutting_down?(inst_ids)
        compare_instance_lists(list(:shutting_down, inst_ids), inst_ids)
      end
      
      def unavailable?(inst_ids)
        instances = list(:any, inst_ids) || []
        instances.reject! { |inst| 
          (inst.state == "shutting-down" || 
           inst.state == "pending" || 
           inst.state == "terminated") 
        }
        compare_instance_lists(instances, inst_ids)
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
        inst.created = h['launchTime']
        inst.keyname = h['keyName']
        inst.launch_index = h['amiLaunchIndex']
        inst.size = h['instanceType']
        inst.dns_private = h['privateDnsName']
        inst.dns_public = h['dnsName']
        inst.reason = h['reason']
        inst.zone = h['placement']['availabilityZone']
        inst.awsid = h['instanceId']
        inst.state = h['instanceState']['name']
        inst
      end
    
      # Is +state+ a known EC2 machine instance state? See: KNOWN_STATES
      def self.known_state?(state)
        return false unless state
        state &&= state.to_sym
        state = :shutting_down if state == :'shutting-down'
        KNOWN_STATES.member?(state)
      end

    private
  
    
      # Find out whether two lists of instance IDs (or Rudy::AWS::EC2::Instance objects)
      # contain the same instances regardless of order. 
      #
      # *+listA+ An Array of instance IDs (Strings) or Rudy::AWS::EC2::Instance objects
      # *+listB+ Another Array of instance IDs (Strings) or Rudy::AWS::EC2::Instance objects
      # Returns true if:
      # * both listA and listB are Arrays
      # * listA and listB contain the same number of items
      # * all items in listA are in listB
      # * all items in listB are in listA
      def compare_instance_lists(listA, listB)
        listA = objects_to_instance_ids(listA)
        listB = objects_to_instance_ids(listB)
        return false if listA.empty? || listB.empty?
        return false unless listA.size == listB.size
        (listA - listB).empty? && (listB - listA).empty? 
      end
    
      # * +inst_ids+ an Array of instance IDs (Strings) or Instance objects.
      # Note: This method removes nil values and always returns an Array.
      # Returns an Array of instances IDs. 
      def objects_to_instance_ids(inst_ids)
        inst_ids = [inst_ids].flatten    # Make sure it's an Array
        inst_ids = inst_ids.collect do |inst|
          next if inst.nil? || inst.to_s.empty?
          if !inst.is_a?(Rudy::AWS::EC2::Instance) && !Rudy::Utils.is_id?(:instance, inst)
            raise %Q("#{inst}" is not an instance ID or object)
          end
          inst.is_a?(Rudy::AWS::EC2::Instance) ? inst.awsid : inst
        end
        inst_ids
      end
  
    end
  end
end

