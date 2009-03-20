
module Rudy
  class Volumes
    include Rudy::Huxtable
    

    def create(zone, size, snapshot=nil)
      raise "No instance supplied" unless zone
      raise "No size supplied" unless size
      switch_user(:root)
      ret = false
      begin
        @logger.print "Creating Volume "
        ret = @ec2.volumes.create(zone, size, snapshot)
        Rudy.waiter(1, 30) do
          @ec2.volumes.available?(ret.awsid)
        end
        puts
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error creating volume: #{ex.message}"
      end
      ret
    end
        
    def attach(volume, instance)
      volume = find_volume(volume)
      raise "No instance supplied" unless instance.is_a?(Rudy::AWS::EC2::Instance)
      raise "No instance id" unless instance.awsid
      raise "Volume #{volume.awsid} already attached" if is_attached?(volume) 
      
      switch_user(:root)
      
      begin
        @logger.print "Attaching Volume "
        ret = @ec2.volumes.attach(instance.awsid, volume.awsid, volume.device)
        # {"attachTime"=>"2009-03-19T13:45:59.000Z", "status"=>"attaching", "device"=>"/dev/sdm", 
        # "requestId"=>"1c494a5d-a727-4fbc-a422-fa70898ca28a", "instanceId"=>"i-f17ae298", 
        # "volumeId"=>"vol-69f71100", "xmlns"=>"http://ec2.amazonaws.com/doc/2008-12-01/"}
        Rudy.waiter(1, 30) do
          is_attached?(volume.awsid)
        end
        puts
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error attaching #{volume.device} to #{volume.awsid}: #{ex.message}"
      end
      true
    end
    
    def destroy(volume)
      volume = find_volume(volume)
      is_attached = is_attached?(volume)
      
      begin
        
        dettach(volume) if is_attached
        raise "Volume is still attached. Cannot destroy." unless @ec2.volumes.available?(volume.awsid)
        
        @logger.print "Destroying #{volume.awsid}"
        @ec2.volumes.destroy(volume.awsid)
        puts
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error destroying volume #{volume.awsid}: #{ex.message}"
      end
    end
    
    def dettach(volume)
      volume = find_volume(volume)
      raise "#{volume.awsid} is not attached" unless @ec2.volumes.attached?(volume.awsid)

      begin
        @logger.print "Dettaching #{volume.awsid} "
        @ec2.volumes.detach(volume.awsid)
        Rudy.waiter(1, 30) do
          @ec2.volumes.available?(volume.awsid)
        end
        puts
      rescue => ex
        puts ex.backtrace if debug?
        raise "Error dettaching volume #{volume.awsid}: #{ex.message}"
      end
    end
    
    
    def is_attached?(volume)
      volume = find_volume(volume)
      @ec2.volumes.available?(volume.awsid)
    end
    
    
    
    # * +volopt* is a volume ID or an Rudy::AWS::EC2::Volume object
    def find_volume(volopt)
      return volopt if volopt.is_a?(Rudy::AWS::EC2::Volume)
      volume = @ec2.volumes.get(volopt)
      raise "Volume #{volopt} not found" unless volume
      volume
    end
    

  end
end