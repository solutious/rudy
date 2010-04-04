

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Volumes < Rudy::CLI::CommandBase
    
      
    def volumes_create_valid?
      raise "You must supply a volume size. See rudy volume -h" unless @option.size
      raise "You must supply a zone." unless @@global.zone
      true
    end
    def volumes_create
      li "Creating #{@option.size}GB volume in #{@@global.zone}"
      execute_check(:low)
      vol = execute_action("Create Failed") { 
        Rudy::AWS::EC2::Volumes.create(@option.size, @@global.zone, @option.snapshot) 
      }
      li @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end


    def destroy_volumes_valid?
      raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid    
      
      unless Rudy::AWS::EC2::Volumes.exists? @argv.volid
        raise Rudy::AWS::EC2::UnknownVolume, @argv.volid
      end
      true
    end
    
    def destroy_volumes
      
      @volume = Rudy::AWS::EC2::Volumes.get(@argv.volid)
      
      raise "Volume #{@volume.awsid} does not exist" unless @volume
      raise "Volume #{@volume.awsid} is still in-use" if @volume.in_use?
      raise "Volume #{@volume.awsid} is still attached" if @volume.attached?
      raise "Volume #{@volume.awsid} is not available (#{@volume.state})" unless @volume.available?
      
      li "Destroying #{@volume.awsid}"
      execute_check(:medium)
      execute_action("Destroy Failed") { 
        Rudy::AWS::EC2::Volumes.destroy(@volume.awsid) 
        true
      }
      
      vol = Rudy::AWS::EC2::Volumes.get(@volume.awsid)

      li @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    
    def volumes_attach_valid?
      raise "You must supply an instance ID." unless @option.instance
      raise "You must supply a volume ID." unless @argv.volid
      true
    end
    def volumes_attach
      @option.device ||= "/dev/sdh"
      raise "Volume #{@argv.volid} does not exist" unless Rudy::AWS::EC2::Volumes.exists?(@argv.volid)
      raise "Volume #{@argv.volid} is already attached" if Rudy::AWS::EC2::Volumes.attached?(@argv.volid)
      raise "Instance #{@option.instance} does not exist" unless Rudy::AWS::EC2::Instances.exists?(@option.instance)
      
      li "Attaching #{@argv.volid} to #{@option.instance} on #{@option.device}"
      execute_check(:low)
      execute_action("Attach Failed") { 
        Rudy::AWS::EC2::Volumes.attach(@argv.volid, @option.instance, @option.device) 
      }
      
      vol = Rudy::AWS::EC2::Volumes.get(@argv.volid)
      li @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    def volumes_detach_valid?
      raise "You must supply a volume ID." unless @argv.volid
      true
    end
    
    def volumes_detach
      raise "Volume #{@argv.volid} does not exist" unless Rudy::AWS::EC2::Volumes.exists?(@argv.volid)
      vol = Rudy::AWS::EC2::Volumes.get(@argv.volid)
      raise "Volume #{vol.awsid} is not attached" unless vol.attached?
      
      li "Detaching #{vol.awsid} from #{vol.instid}"
      execute_check(:medium)
      execute_action("Detach Failed") { Rudy::AWS::EC2::Volumes.detach(vol.awsid) }
      
      vol = Rudy::AWS::EC2::Volumes.get(vol.awsid)
      li @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    
    def volumes
      volumes = Rudy::AWS::EC2::Volumes.list || []
      volumes.each do |vol|
        li @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
      end
    end
    
  end

end; end
end; end
