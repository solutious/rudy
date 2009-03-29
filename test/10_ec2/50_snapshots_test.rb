
module Rudy::Test
  class EC2


       
   context "(50) #{name} Snapshots" do
     
     should "(00) be no snapshots" do
       stop_test @@ec2.snapshots.any?, "Destroy existing snapshots"
     end
     
     should "(01) create a volume to work off of" do
       @@volumes ||= []
       @@volumes << @@ec2.volumes.create(@@zone, 1)
       stop_test !@@volumes.first.is_a?(Rudy::AWS::EC2::Volume), "No volume to work off of."
     end
     
     should "(01) create snapshot" do
       assert !@@volumes.first.awsid.empty?, "No volume ID"
       @@ec2.snapshots.create(@@volumes.first.awsid)
     end
     
     should "(10) list snapshots" do
       snap_list = @@ec2.snapshots.list
       assert snap_list.is_a?(Array), "Not an Array"
       assert snap_list.size > 0, "No Snapshots in Array"
        
       snap_hash = @@ec2.snapshots.list_as_hash
       assert snap_hash.is_a?(Hash), "Not an Hash"
       assert snap_hash.keys.size > 0, "No Snapshots in Hash"
     end
     
     should "(20) create volume from snapshot" do
       volume_size = 2
       snap_list = @@ec2.snapshots.list || []
       assert !snap_list.empty?, "No snapshots"
        
       volume = @@ec2.volumes.create(@@zone, volume_size, snap_list.first.awsid)
       #puts "#{volume.awsid} #{snap_list.first.awsid}"
       
       assert volume.is_a?(Rudy::AWS::EC2::Volume), "Not a Volume"
       assert_equal @@zone, volume.zone, "Zone incorrect: #{volume.zone}"
       assert_equal snap_list.first.awsid, volume.snapid, "Snapshot mismatch: #{volume.snapid}"
       assert_equal volume_size.to_i, volume.size.to_i, "Size incorrect: #{volume.size}"
       assert volume.creating? || volume.available?, "Volume not creating or available (#{volume.status})"
       
       @@volumes << volume # We put it here so it will be destoryed in teardown
     end
     
     should "(50) destroy snapshots" do
       assert @@ec2.snapshots.any?, "No snapshots"
       snap_list = @@ec2.snapshots.list
       snap_list.each do |snap|
         next unless snap.completed?
         assert @@ec2.snapshots.destroy(snap.awsid), "Not destroyed (#{snap.awsid})"
       end
     end
     
     should "(99) cleanup created volumes" do
       (@@volumes || []).each do |vol|
         assert @@ec2.volumes.destroy(vol), "Volume not destoryed (#{vol.awsid})"
       end
     end
   end
  
  end
end