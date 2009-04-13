

module Rudy::AWS
  module EC2
    class Snapshot < Storable
      field :awsid
      field :progress
      field :created
      field :volid
      field :status
      
      def to_s
        "%s:%s (%s) %s" [self.awsid, self.volid, self.created, self.status]
      end
      
      def completed?
        self.status && self.status == 'completed'
      end
      
    end
    
    class Snapshots
      include Rudy::AWS::ObjectBase
      

      def list(*snap_id)
        snapshots = list_as_hash(snap_id)
        snapshots &&= snapshots.values
        snapshots
      end
      def list_as_hash(*snap_id)
        snap_id = snap_id.flatten
        slist = @aws.describe_snapshots(:snapshot_id => snap_id)
        return unless slist['snapshotSet'].is_a?(Hash)
        snapshots = {}
        slist['snapshotSet']['item'].each do |snap| 
          kp = self.class.from_hash(snap)
          snapshots[kp.awsid] = kp
        end
        snapshots
      end
      
      def create(vol_id)
        vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
        snap = @aws.create_snapshot(:volume_id => vol_id)
        self.class.from_hash(snap)
      end
      
      def destroy(snap_id)
        ret = @aws.delete_snapshot(:snapshot_id => snap_id)
        (ret && ret['return'] == 'true') 
      end
      
      
      def Snapshots.from_hash(h)
        #snapshotSet: 
        #  item: 
        #  - snapshotId: snap-5493653d
        #    volumeId: vol-0836d761
        #    status: completed
        #    startTime: "2009-03-29T20:15:10.000Z"
        #    progress: 100%
        vol = Rudy::AWS::EC2::Snapshot.new
        vol.awsid = h['snapshotId']
        vol.volid = h['volumeId']
        vol.created = h['startTime']
        vol.progress = h['progress']
        vol.status = h['status']
        vol 
      end
      
      def any?
        !(list_as_hash || {}).empty?
      end
      
      def get(snap_id)
        list(snap_id).first || nil
      end
      
      def exists?(id)
        !get(snap_id).nil?
      end
      
    end
    
  end
end