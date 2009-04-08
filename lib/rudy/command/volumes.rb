
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
      instance = instance.is_a?(Rudy::AWS::EC2::Instance) ? instance.awsid : instance
      raise "Volume #{volume.awsid} already attached" if volume.attached?
      raise "No instance supplied" unless instance
      raise "No device supplied" unless device
      
      ret = false
      begin
        @logger.puts "Attaching Volume... "
        ret = @@ec2.volumes.attach(instance, volume.awsid, device)
        raise "Unknown error" unless ret 
        
        Rudy.waiter(1, 30, @logger) do
          ret = attached?(volume.awsid)
        end
        
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error attaching #{volume.awsid} to #{instance}: #{ex.message}"
      end
      
      ret
    end
    
    def destroy(volume)
      volume = get(volume)
      
      
      ret = false
      begin
        
        detach(volume) if volume.attached?
        raise "Volume is still attached. Cannot destroy." unless available?(volume.awsid)
        
        ret = @@ec2.volumes.destroy(volume.awsid)
        
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error destroying volume #{volume.awsid}: #{ex.message}"
      end
      ret
    end
     
    def detach(volume)
      volume = get(volume)
      raise "#{volume.awsid} is not attached" unless attached?(volume.awsid)
      
      ret = false
      begin
        @logger.puts "Dettaching #{volume.awsid} "
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
    
    def in_use?(volume)
      @@ec2.volumes.in_use?(volume)
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