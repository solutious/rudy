

module Rudy::Test
  class Case_50_Commands
    
    context "#{name}_40 Volumes" do
      
      setup do
        @rvol = Rudy::Volumes.new(:logger => @@logger)
        stop_test !@rvol.is_a?(Rudy::Volumes), "We need Rudy::Volumes (#{@rvol})"
      end
      
      should "(10) create a volume" do
        volume_size = 2
        #stop_test @rvol.any?(:available), "Destroy existing volumes"
        volume = @rvol.create(volume_size)
        assert volume.is_a?(Rudy::AWS::EC2::Volume), "Not a Volume"
        # Should use the global zone by default
        assert_equal @rvol.global.zone.to_s, volume.zone, "Zone incorrect: #{volume.zone}"
        assert_equal volume_size.to_i, volume.size.to_i, "Size incorrect: #{volume.size}"
        # Rudy::Volume should wait until the volume is available before returning
        assert volume.available?, "Volume not available (#{volume.status})"
      end
      
      should "(11) list a volume as available" do
        
      end
      
      should "(20) list volumes" do
         volume_list = @rvol.list
         assert volume_list.is_a?(Array), "Not an Array"
         assert volume_list.size > 0, "No Volumes in Array"

         volume_hash = @rvol.list_as_hash
         assert volume_hash.is_a?(Hash), "Not a Hash"
         assert volume_hash.keys.size > 0, "No Volumes in Hash"

         assert_equal volume_list.size.to_i, volume_hash.keys.size.to_i, "Hash and Array not equal size"
       end
       
      should "(90) destroy volumes" do
        assert @rvol.any?, "No volumes"
        volume_list = @rvol.list
        volume_list.each do |vol|
          next unless vol.available?
          ret = @rvol.destroy(vol.awsid)
          assert ret, "Not destroyed (#{ret} for #{vol.awsid})"
          assert @rvol.deleting?(vol.awsid), "Volume not in deleting state (#{vol.awsid}: #{vol.state})"
        end
      end
    end
    
  end
end
    