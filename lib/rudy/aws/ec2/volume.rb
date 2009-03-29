

module Rudy::AWS
  class EC2
    class Volume < Storable
    field :awsid
    field :status
    field :size
    field :snapid
    field :zone
    field :create_time
    field :attach_time
    field :instid
    field :device
    
    def to_s
      lines = ["Volume: #{self.awsid.bright}"]
      field_names.each do |n|
         lines << sprintf(" %12s: %s", n, self.send(n)) if self.send(n)
       end
      lines.join($/)
    end
    
    def available?
      (status && status == "available")
    end
    
    def creating?
      (status && status == "creating")
    end
    
    def deleting?
      (status && status == "deleting")
    end
    
    def attached?
      (status && (status == "in-use" || status == "attached"))
    end
    
  end
  
  
  class EC2::Volumes
    include Rudy::AWS::ObjectBase
    
    def attach(inst_id, vol_id, device)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      inst_id = inst_id.is_a?(Rudy::AWS::EC2::Instace) ? inst_id.awsid : inst_id
      @aws.attach_volume(:volume_id => vol_id, :instance_id => inst_id, :device => device)
    end
    
    def detach(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      @aws.detach_volume(:volume_id => vol_id)
    end
    
    
    def list(vol_id=[])
      list_as_hash(vol_id).values
    end
    
    def list_as_hash(vol_id=[])
      opts = { 
        :volume_id => vol_id ? [vol_id].flatten : [] 
      }
      begin
        vlist = @aws.describe_volumes(opts) || {}
      # NOTE: The InternalError is returned for non-existent volume IDs. 
      # It's probably a bug so we're ignoring it -- Dave. 
      rescue ::EC2::InternalError => ex 
        vlist = {}
      end
      volumes = {}
      return volumes unless vlist['volumeSet'].is_a?(Hash)
      vlist['volumeSet']['item'].each do |vol|
        v = Volumes.from_hash(vol)
        volumes[v.awsid] = v
      end
      volumes
    end
    
    
    # * +size+ the number of GB
    def create(zone, size, snapid=nil)
      opts = {
        :availability_zone => zone,
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
      vol = @aws.create_volume(opts) || {}
      reqid = vol['requestId']
      Volumes.from_hash(vol) || nil
    end
    
    def self.from_hash(h)
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
      vol.snapid = h['snapshotId']
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
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      ret = @aws.delete_volume(:volume_id => vol_id)
      (ret && ret['return'] == 'true') 
    end
    
    def any?
      !(list || []).empty?
    end
    
    def exists?(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      !get(vol_id).nil?
    end
    
    def get(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      list(vol_id).first || nil
    end
    
    def deleting?(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      return false unless vol_id
      vol = get(vol_id)
      (vol && vol.status == "deleting")
    end
    
    def available?(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      return false unless vol_id
      vol = get(vol_id)
      (vol && vol.status == "available")
    end
    
    def attached?(vol_id)
      vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
      return false unless vol_id
      vol = get(vol_id)
      (vol && (vol.status == "in-use" || vol.status == "attached"))
    end
      
  end
end
end