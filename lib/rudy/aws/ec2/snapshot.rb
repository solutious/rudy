

module Rudy::AWS
  module EC2
    class Snapshot < Storable
      
      field :awsid
      field :progress
      field :created
      field :volid
      field :status
      
      def to_s(with_title=false)
        [@awsid.bright, @volid, @created, @status, @progress].join '; '
      end
      
      def completed?
        self.status && self.status == 'completed'
      end
      
    end
    
    module Snapshots
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend


      def list(snap_id=[])
        snapshots = list_as_hash(snap_id)
        if snapshots
          snapshots = snapshots.values.sort { |a,b| a.created <=> b.created }
        end
        snapshots
      end
      def list_as_hash(snap_id=[])
        snap_id = [snap_id].flatten.compact
        slist = @@ec2.describe_snapshots(:snapshot_id => snap_id)
        return unless slist['snapshotSet'].is_a?(Hash)
        snapshots = {}
        slist['snapshotSet']['item'].each do |snap| 
          kp = self.from_hash(snap)
          snapshots[kp.awsid] = kp
        end
        snapshots = nil if snapshots.empty?
        snapshots
      end
      
      def create(vol_id)
        vol_id = (vol_id.is_a?(Rudy::AWS::EC2::Volume)) ? vol_id.awsid : vol_id
        shash = @@ec2.create_snapshot(:volume_id => vol_id)
        snap = Snapshots.from_hash(shash)
        snap
      end
      
      def destroy(snap_id)
        ret = @@ec2.delete_snapshot(:snapshot_id => snap_id)
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
        list(snap_id).first rescue nil
      end
      
      def exists?(snap_id)
        !get(snap_id).nil?
      end
      
      def completed?(snap_id)
        s = get(snap_id)
        return false if s.nil?
        s.completed?
      end
    end
    
  end
end