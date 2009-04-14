
module Rudy::Test
  class Case_25_EC2


       
   context "#{name}_50 Snapshots" do
     setup do
       @ec2vol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
       @ec2snap = Rudy::AWS::EC2::Snapshots.new(@@global.accesskey, @@global.secretkey)
     end
     
     
     should "(00) be no snapshots" do
       stop_test @ec2snap.any?, "Destroy existing snapshots"
     end
     
     should "(01) create a volume to work off of" do
       @@volumes ||= []
       @@volumes << @ec2vol.create(1, @@zone)
       stop_test !@@volumes.first.is_a?(Rudy::AWS::EC2::Volume), "No volume to work off of."
     end
     
     should "(01) create snapshot" do
       stop_test !@@volumes.first.is_a?(Rudy::AWS::EC2::Volume), "No volume to work off of."
       assert !@@volumes.first.awsid.empty?, "No volume ID"
       @ec2snap.create(@@volumes.first.awsid)
     end
     
     should "(10) list snapshots" do
       snap_list = @ec2snap.list
       assert snap_list.is_a?(Array), "Not an Array"
       assert snap_list.size > 0, "No Snapshots in Array"
        
       snap_hash = @ec2snap.list_as_hash
       assert snap_hash.is_a?(Hash), "Not an Hash"
       assert snap_hash.keys.size > 0, "No Snapshots in Hash"
     end
     
     should "(20) create volume from snapshot" do
       volume_size = 2
       snap_list = @ec2snap.list || []
       assert !snap_list.empty?, "No snapshots"
        
       volume = @ec2vol.create(volume_size, @@zone, snap_list.first.awsid)
       #puts "#{volume.awsid} #{snap_list.first.awsid}"
       
       assert volume.is_a?(Rudy::AWS::EC2::Volume), "Not a Volume"
       assert_equal @@zone, volume.zone, "Zone incorrect: #{volume.zone}"
       assert_equal snap_list.first.awsid, volume.snapid, "Snapshot mismatch: #{volume.snapid}"
       assert_equal volume_size.to_i, volume.size.to_i, "Size incorrect: #{volume.size}"
       assert volume.creating? || volume.available?, "Volume not creating or available (#{volume.status})"
       
       @@volumes << volume # We put it here so it will be destoryed in teardown
     end
     
     should "(90) destroy snapshots" do
       assert @ec2snap.any?, "No snapshots"
       snap_list = @ec2snap.list
       snap_list.each do |snap|
         next unless snap.completed?
         assert @ec2snap.destroy(snap.awsid), "Not destroyed (#{snap.awsid})"
       end
     end
     
     should "(99) cleanup created volumes" do
       (@@volumes || []).each do |vol|
         assert @ec2vol.destroy(vol), "Volume not destoryed (#{vol.awsid})"
       end
     end
   end
  
  end
end