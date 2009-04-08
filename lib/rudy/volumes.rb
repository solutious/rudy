
module Rudy
  class Volumes
    include Rudy::Huxtable
    

    def create(size, zone=nil, snapshot=nil)
      raise "No size supplied" unless size
      zone ||= @global.zone
      
      @logger.puts "Creating Volume "
      vol = @@ec2.volumes.create(size, zone, snapshot)
      Rudy.waiter(1, 30, @logger) do
        vol = get(vol.awsid) # update the volume until it says it's available
        (vol && vol.status == "available")
      end
      
      vol
    end
        
    def attach(volume, instance)
      volume = get(volume)
      raise "No instance supplied" unless instance.is_a?(Rudy::AWS::EC2::Instance)
      raise "No instance id" unless instance.awsid
      raise "Volume #{volume.awsid} already attached" if attached?(volume) 
      
      switch_user(:root)
      
      begin
        @logger.print "Attaching Volume "
        volume = @@ec2.volumes.attach(instance.awsid, volume.awsid, volume.device)
        # {"attachTime"=>"2009-03-19T13:45:59.000Z", "status"=>"attaching", "device"=>"/dev/sdm", 
        # "requestId"=>"1c494a5d-a727-4fbc-a422-fa70898ca28a", "instanceId"=>"i-f17ae298", 
        # "volumeId"=>"vol-69f71100", "xmlns"=>"http://ec2.amazonaws.com/doc/2008-12-01/"}
        Rudy.waiter(1, 30, @logger) do
          attached?(volume.awsid)
        end
        
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error attaching #{volume.device} to #{volume.awsid}: #{ex.message}"
      end
      
      attached?(volume.awsid)
    end
    
    def destroy(volume)
      volume = get(volume)
      is_attached = attached?(volume)
      
      ret = false
      begin
        
        detach(volume) if is_attached
        raise "Volume is still attached. Cannot destroy." unless @@ec2.volumes.available?(volume.awsid)
        
        @logger.puts "Destroying #{volume.awsid}"
        ret = @@ec2.volumes.destroy(volume.awsid)
        
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error destroying volume #{volume.awsid}: #{ex.message}"
      end
      ret
    end
     
    def detach(volume)
      volume = get(volume)
      raise "#{volume.awsid} is not attached" unless @@ec2.volumes.attached?(volume.awsid)

      begin
        @logger.print "Dettaching #{volume.awsid} "
        @@ec2.volumes.detach(volume.awsid)
        Rudy.waiter(1, 30) do
          @@ec2.volumes.available?(volume.awsid)
        end
        
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error detaching volume #{volume.awsid}: #{ex.message}"
      end
      
      available?(volume.awsid)
    end
    
    
    def attached?(volume)
      @@ec2.volumes.attached?(volume)
    end
    
    def deleting?(volume)
      @@ec2.volumes.deleting?(volume)
    end
    
    def available?(volume)
      @@ec2.volumes.available?(volume)
    end
    
    
    def list(state=nil, vol_id=[])
      @@ec2.volumes.list(state, vol_id)
    end
    
    def list_as_hash(state=nil, vol_id=[])
      @@ec2.volumes.list_as_hash(state, vol_id)
    end
    
    def any?(state=nil, vol_id=[])
      @@ec2.volumes.any?(state, vol_id)
    end
    
    def exists?(vol_id)
      @@ec2.volumes.exists?(vol_id)
    end
    
    # * +volopt* is a volume ID or an Rudy::AWS::EC2::Volume object
    def get(volopt)
      return volopt if volopt.is_a?(Rudy::AWS::EC2::Volume)
      @@ec2.volumes.get(volopt)
    end
    

  end
end