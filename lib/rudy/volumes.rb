
module Rudy
  class Volumes
    include Rudy::Huxtable


    
    def attach(inst_id, vol_id, device)
      raise "No instance supplied" unless inst_id
      switch_user(:root)
      
      begin
        @logger.puts "Attaching Volume "
        ret = @ec2.volumes.attach(inst_id, vol_id, device)
        # {"attachTime"=>"2009-03-19T13:45:59.000Z", "status"=>"attaching", "device"=>"/dev/sdm", 
        # "requestId"=>"1c494a5d-a727-4fbc-a422-fa70898ca28a", "instanceId"=>"i-f17ae298", 
        # "volumeId"=>"vol-69f71100", "xmlns"=>"http://ec2.amazonaws.com/doc/2008-12-01/"}
        Rudy.waiter(2, 30) do
          @ec2.volumes.attached?(vol_id)
        end
        puts
      rescue Timeout::Error => ex
        puts "Moving on..."
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error attaching #{device} to #{vol_id}: #{ex.message}"
      end
      true
    end
    
    def destroy(vol_id)
      begin
        if @ec2.volumes.attached?(vol_id)
          dettach(vol_id)
        end
        
        raise "Volume is still attached. Cannot destroy." unless @ec2.volumes.available?(vol_id)
        
        @logger.puts "Destroying #{vol_id}"
        @ec2.volumes.destroy(vol_id)
        puts
      rescue => ex
        puts "Error while destroying volume #{vol_id}: #{ex.message}"
        puts ex.backtrace if debug?
      end
    end
    
    def dettach(vol_id)
      raise "#{vol_id} is not attached" unless @ec2.volumes.attached?(vol_id)

      begin
        @logger.print "Dettaching #{vol_id} "
        @ec2.volumes.detach(vol_id)
        Rudy.waiter(2, 30) do
          @ec2.volumes.available?(vol_id)
        end
        puts
      rescue Timeout::Error => ex
        puts "Moving on..."
      rescue => ex
        puts "Error while dettaching volume #{vol_id}: #{ex.message}"
        puts ex.backtrace if debug?
      end
    end
    

  end
end