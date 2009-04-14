

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Volumes < Rudy::CLI::Base
    
      
    def volumes_create_valid?
      raise "You must supply a volume size. See rudy volume -h" unless @option.size
      raise "You must supply a zone." unless @@global.zone
      true
    end
    def volumes_create
      puts "Creating #{@option.size}GB volume in #{@@global.zone}"
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      execute_check(:low)
      vol = execute_action("Create Failed") { 
        rvol.create(@option.size, @@global.zone, @option.snapshot) 
      }
      puts @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end


    def destroy_volumes_valid?
      raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid      
      true
    end
    
    def destroy_volumes
      @rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      @volume = @rvol.get(@argv.volid)
      raise "Volume #{@volume.awsid} does not exist" unless @volume
      raise "Volume #{@volume.awsid} is still in-use" if @volume.in_use?
      raise "Volume #{@volume.awsid} is still attached" if @volume.attached?
      raise "Volume #{@volume.awsid} is not available (#{@volume.state})" unless @volume.available?
      
      puts "Destroying #{@volume.awsid}"
      execute_check(:medium)
      execute_action("Destroy Failed") { @rvol.destroy(@volume.awsid) }
      
      vol = @rvol.get(@volume.awsid)
      puts @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    
    def volumes_attach_valid?
      raise "You must supply an instance ID." unless @option.instance
      raise "You must supply a volume ID." unless @argv.volid
      true
    end
    def volumes_attach
      @option.device ||= "/dev/sdh"
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      raise "Volume #{@argv.volid} does not exist" unless rvol.exists?(@argv.volid)
      raise "Volume #{@argv.volid} is already attached" if rvol.attached?(@argv.volid)
      raise "Instance #{@option.instance} does not exist" unless rinst.exists?(@option.instance)
      
      puts "Attaching #{@argv.volid} to #{@option.instance} on #{@option.device}"
      execute_check(:low)
      execute_action("Attach Failed") { 
        rvol.attach(@argv.volid, @option.instance, @option.device) 
      }
      
      vol = rvol.get(@argv.volid)
      puts @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    def volumes_detach_valid?
      raise "You must supply a volume ID." unless @argv.volid
      true
    end
    
    def volumes_detach
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      raise "Volume #{@argv.volid} does not exist" unless rvol.exists?(@argv.volid)
      
      vol = rvol.get(@argv.volid)
      raise "Volume #{vol.awsid} is not attached" unless vol.attached?
      
      puts "Detaching #{vol.awsid} from #{vol.instid}"
      execute_check(:medium)
      execute_action("Detach Failed") { rvol.detach(vol.awsid) }
      
      vol = rvol.get(vol.awsid)
      puts @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
    end
    
    
    def volumes
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      volumes = rvol.list || []
      volumes.each do |vol|
        puts @global.verbose > 1 ? vol.inspect : vol.dump(@@global.format)
      end
      puts "No volumes" if volumes.empty?
    end
    
  end

end; end
end; end
