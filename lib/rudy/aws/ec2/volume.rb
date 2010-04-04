

module Rudy::AWS
  module EC2
    class Volume < Storable
      @@sformat = "%s  %10s;%4sGB;  %s  " # cram the terabyte
      
      field :size  => Integer
      field :zone  => Symbol
      field :created => Time
      field :attached => Time
      field :awsid
      field :status
      field :snapid
      field :instid
      field :device
    
      def postprocess
        @zone &&= @zone.to_sym
        @size &&= @size.to_i
      end
      
      def to_s(*args)
        [@awsid.bright, @zone, @size, @created, @instid, @snapid].join '; '
      end
    
      # Alias for status
      def state
        status
      end
    
      def available?; (status && status == "available"); end
      def creating?; (status && status == "creating"); end
      def deleting?; (status && status == "deleting"); end
      def attached?; (status && status == "attached"); end
      def in_use?; (status && status == "in-use"); end
    
    end
  
  
    module Volumes
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
      
      
      unless defined?(KNOWN_STATES)
        KNOWN_STATES = [:available, :creating, :deleting, :attached, :detaching].freeze 
      end
    
      # * +size+ the number of GB
      def create(size, zone, snapid=nil)
        opts = {
          :availability_zone => zone.to_s,
          :size => (size || 1).to_s
        }
      
        opts[:snapshot_id] = snapid if snapid
      
        # "status"=>"creating", 
        # "size"=>"1", 
        # "snapshotId"=>nil, 
        # "requestId"=>"d42ff744-48b5-4f47-a3f0-7aba57a13eb9", 
        # "availabilityZone"=>"us-east-1b", 
        # "createTime"=>"2009-03-17T20:10:48.000Z", 
        # "volumeId"=>"vol-48826421"
        vol = Rudy::AWS::EC2.execute_request({}) { @@ec2.create_volume(opts) }
      
        # TODO: use a waiter?
        #Rudy.waiter(1, 30) do
        #  ret = @@@ec2.volumes.available?(volume.awsid)
        #end
      
        reqid = vol['requestId']
        Volumes.from_hash(vol) || nil
      end
    
      def destroy(vol_id)
        vol_id = Volumes.get_vol_id(vol_id)
        raise VolumeNotAvailable, vol_id unless available?(vol_id)
        ret = Rudy::AWS::EC2.execute_request({}) { @@ec2.delete_volume(:volume_id => vol_id) }
        (ret['return'] == 'true') 
      end
    
      def attach(vol_id, inst_id, device)
        vol_id = Volumes.get_vol_id(vol_id)
        inst_id = inst_id.is_a?(Rudy::AWS::EC2::Instance) ? inst_id.awsid : inst_id
        raise NoVolumeID unless vol_id
        raise VolumeAlreadyAttached, vol_id if attached?(vol_id)
        raise NoInstanceID unless inst_id
        raise NoDevice unless device
      
        opts = {
          :volume_id => vol_id, 
          :instance_id => inst_id, 
          :device => device.to_s    # Solaris devices are numbers
        }
        ret = Rudy::AWS::EC2.execute_request(false) { @@ec2.attach_volume(opts) }
        (ret['status'] == 'attaching')
      end
    
      def detach(vol_id)
        vol_id = Volumes.get_vol_id(vol_id)
        raise NoVolumeID unless vol_id
        raise VolumeNotAttached, vol_id unless attached?(vol_id)
        ret = Rudy::AWS::EC2.execute_request({}) { 
          @@ec2.detach_volume(:volume_id => vol_id) 
        }
        (ret['status'] == 'detaching') 
      end
    
    
      def list(state=nil, vol_id=[], &each_vol)
        volumes = list_as_hash(state, vol_id, &each_vol)
        volumes &&= volumes.values
        volumes
      end
    
      def list_as_hash(state=nil, vol_id=[], &each_vol)
        state &&= state.to_sym
        state = nil if state == :any
        # A nil state is fine, but we don't want an unknown one!
        raise UnknownState, state if state && !Volumes.known_state?(state)
      
        opts = { 
          :volume_id => vol_id ? [vol_id].flatten : [] 
        }

        vlist = Rudy::AWS::EC2.execute_request({}) { 
          @@ec2.describe_volumes(opts) 
        }

        volumes = {}
        return volumes unless vlist['volumeSet'].is_a?(Hash)
        vlist['volumeSet']['item'].each do |vol|
          v = Volumes.from_hash(vol)
          next if state && v.state != state.to_s
          volumes[v.awsid] = v
        end
        volumes.values.each { |v| each_vol.call(v) } if each_vol
        volumes = nil if volumes.empty?
        volumes
      end
      
      def list_by_instance(instid, &each_vol)
        instid = instid.awsid if instid.is_a? Rudy::AWS::EC2::Instance
        volumes = list(:attached, &each_vol)
        volumes &&= volumes.select { |v| v.instid == instid }
        volumes
      end
      
      def any?(state=nil,vol_id=[])
        vols = list(state, vol_id)
        !vols.nil?
      end
    
      def exists?(vol_id)
        vol_id = Volumes.get_vol_id(vol_id)
        vol = get(vol_id)
        return false if vol.nil?
        return false if vol.deleting?
        !vol.nil?
      end
    
      def get(vol_id)
        vol_id = Volumes.get_vol_id(vol_id)
        list(:any, vol_id).first rescue nil
      end
    
      # deleting?, available?, etc...
      %w[deleting available attached in-use].each do |state|
        define_method("#{state.tr('-', '_')}?") do |vol_id|
          vol_id = Volumes.get_vol_id(vol_id)
          return false unless vol_id
          vol = get(vol_id)
          (vol && vol.status == state) ? true : false
        end
      end
    
      # Creates a Rudy::AWS::EC2::Volume object from:
      #
      #     volumeSet: 
      #       item: 
      #       - status: available
      #         size: "1"
      #         snapshotId: 
      #         availabilityZone: us-east-1b
      #         attachmentSet: 
      #         createTime: "2009-03-17T20:10:48.000Z"
      #         volumeId: vol-48826421
      #         attachmentSet: 
      #           item: 
      #           - attachTime: "2009-03-17T21:49:54.000Z"
      #             status: attached
      #             device: /dev/sdh
      #             instanceId: i-956af3fc
      #             volumeId: vol-48826421
      #         
      #     requestId: 8fc30e5b-a9c3-4fe0-a979-0f71e639a7c7
      #
      def self.from_hash(h)
        vol = Rudy::AWS::EC2::Volume.new
        vol.status = h['status']
        vol.size = h['size']
        vol.snapid = h['snapshotId']
        vol.zone = h['availabilityZone']
        vol.awsid = h['volumeId']
        vol.created = h['createTime']
        if h['attachmentSet'].is_a?(Hash)
          item = h['attachmentSet']['item'].first
          vol.status = item['status']   # Overwrite "available status". Possibly a bad idea. 
          vol.device = item['device']
          vol.attached = item['attachTime']
          vol.instid = item['instanceId']
        end
        vol.postprocess
        vol
      end

      # * +vol_id+ is a String or Rudy::AWS::EC2::Volume
      # Returns the volume ID
      def self.get_vol_id(vol_id)
        (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      end

      # Is +state+ a known EC2 volume state? See: KNOWN_STATES
      def self.known_state?(state)
        return false unless state
        state &&= state.to_sym
        KNOWN_STATES.member?(state)
      end
    
    end
  end
end

