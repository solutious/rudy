group "EC2"
library :rudy, 'lib'

tryouts "Snapshots" do
  set :global, Rudy::Huxtable.global
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
    Rudy::AWS::EC2::Volumes.create 3, global.zone
  end
  clean do
    Rudy::AWS::EC2::Volumes.list(:available) do |v|
      Rudy::AWS::EC2::Volumes.destroy v
    end
  end
  
  drill "no existing snapshots", false do
    Rudy::AWS::EC2::Snapshots.any?
  end
  
    dream :class, Rudy::AWS::EC2::Snapshot
  drill "create snapshot" do
    vol = Rudy::AWS::EC2::Volumes.list(:available).first
    Rudy::AWS::EC2::Snapshots.create vol.awsid
  end
  
    dream :class, Array
    dream :empty?, false
  drill "list snapshots as Array" do
    Rudy::AWS::EC2::Snapshots.list
  end

    dream :class, Hash
    dream :empty?, false
  drill "list snapshots as Hash" do
    Rudy::AWS::EC2::Snapshots.list_as_hash
  end
  
    dream :class, Rudy::AWS::EC2::Snapshot
  drill "get snapshot from id" do
    snap = Rudy::AWS::EC2::Snapshots.list.first
    Rudy::AWS::EC2::Snapshots.get snap.awsid
  end
  
    dream :class, Rudy::AWS::EC2::Volume
    dream :size, 3
    dream :proc, lambda { |v| v.creating? || v.available? }
    dream :proc, lambda { |v|
      snap = Rudy::AWS::EC2::Snapshots.list.first
      v.snapid == snap.awsid
    }
  drill "create volume from snapshot" do
    snap = Rudy::AWS::EC2::Snapshots.list.first
    Rudy::AWS::EC2::Volumes.create 3, global.zone, snap.awsid
  end
  
  drill "destroy snapshots", false do
    Rudy::AWS::EC2::Snapshots.list.each do |snap|
      Rudy::AWS::EC2::Snapshots.destroy snap.awsid
    end
    Rudy::AWS::EC2::Snapshots.any?
  end
end

__END__

 
 should "(90) destroy snapshots" do
   assert @ec2snap.any?, "No snapshots"
   snap_list = @ec2snap.list
   snap_list.each do |snap|
     next unless snap.completed?
     assert @ec2snap.destroy(snap.awsid), "Not destroyed (#{snap.awsid})"
   end
 end