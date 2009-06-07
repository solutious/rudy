
module Rudy::Test
  class Case_25_EC2
    
    context "#{name}_40 Volumes" do
      setup do
        @ec2vol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey, @@global.region)
      end
      
      should "(00) not be existing volumes" do
        volume_hash = @ec2vol.list_as_hash
        volume_hash.reject! { |volid, vol| !vol.available? }
        stop_test !volume_hash.empty?, "Destroy the existing volumes"
      end

      should "(10) create volume" do 
        volume_size = 2
        volume = @ec2vol.create(volume_size, @@zone)
        assert volume.is_a?(Rudy::AWS::EC2::Volume), "Not a Volume"
        assert_equal @@zone, volume.zone, "Zone incorrect: #{volume.zone}"
        assert_equal volume_size.to_i, volume.size.to_i, "Size incorrect: #{volume.size}"
        assert volume.creating? || volume.available?, "Volume not creating or available (#{volume.status})"
      end

      should "(20) list volumes" do
        volume_list = @ec2vol.list
        assert volume_list.is_a?(Array), "Not an Array"
        assert volume_list.size > 0, "No Volumes in Array"

        volume_hash = @ec2vol.list_as_hash
        assert volume_hash.is_a?(Hash), "Not a Hash"
        assert volume_hash.keys.size > 0, "No Volumes in Hash"

        assert_equal volume_list.size.to_i, volume_hash.keys.size.to_i, "Hash and Array not equal size"
      end

      should "(50) destroy volumes" do
        assert @ec2vol.any?, "No volumes"
        volume_list = @ec2vol.list
        volume_list.each do |vol|
          next unless vol.available?
          assert @ec2vol.destroy(vol.awsid), "Not destroyed (#{vol.awsid})"
        end
      end
 
    end 
    
  end
end