
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
        
    def attach(volume, instance, device="/dev/sdh")
      volume = get(volume)
      raise "No instance supplied" unless instance.is_a?(Rudy::AWS::EC2::Instance)
      raise "No instance id" unless instance.awsid
      raise "No device supplied" unless device
      raise "Volume #{volume.awsid} already attached" if attached?(volume) 
      
      ret = false
      begin
        @logger.print "Attaching Volume "
        ret = @@ec2.volumes.attach(instance.awsid, volume.awsid, device)
        raise "Unknown error" unless ret 
        
        Rudy.waiter(1, 30, @logger) do
          ret = attached?(volume.awsid)
        end
        
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error attaching #{volume.awsid} to #{instance.awsid}: #{ex.message}"
      end
      
      ret
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
      
      ret = false
      begin
        @logger.print "Dettaching #{volume.awsid} "
        @@ec2.volumes.detach(volume.awsid)
        Rudy.waiter(1, 30) do
          ret = @@ec2.volumes.available?(volume.awsid)
        end
        
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error detaching volume #{volume.awsid}: #{ex.message}"
      end
      
      ret
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