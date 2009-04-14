

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Volumes < Rudy::CLI::Base
    
      
    def volumes_create_valid?
      raise "You must supply a volume size. See rudy volume -h" unless @option.size
      raise "You must supply a zone." unless @@global.zone
      true
    end
    def volumes_create
      puts "Volumes".bright
      
      puts "Creating #{@option.size}GB volume in #{@@global.zone}"
      exit unless Annoy.are_you_sure?(:medium)
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      vol = rvol.create(@option.size, @@global.zone, @option.snapshot)
      
      puts
      puts @global.verbose > 0 ? vol.inspect : vol.to_s
    end


    def destroy_volumes_valid?
      raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid      
      true
    end
    
    def destroy_volumes
      puts "Volumes".bright
      
      @rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      
      @volume = @rvol.get(@argv.volid)
      
      raise "Volume #{@argv.volid} does not exist" unless @volume
      
      raise "Volume #{@argv.volid} is still in-use" if @volume.in_use?
      raise "Volume #{@argv.volid} is still attached" if @volume.attached?
      raise "Volume #{@argv.volid} is not available (#{@volume.state})" unless @volume.available?
      
      puts "Destroying #{@volume.awsid}"
      exit unless Annoy.are_you_sure?(:medium)
      
      ret = @rvol.destroy(@volume.awsid)
      raise "Failed" unless ret
      
      vol = @rvol.get(@volume.awsid)
      
      puts
      puts @global.verbose > 0 ? vol.inspect : vol.to_s
    end
    
    
    def volumes_attach_valid?
      raise "You must supply a volume ID." unless @argv.volid
      raise "You must supply an instance ID." unless @option.instance
      
      true
    end
    def volumes_attach
      puts "Volumes".bright
      
      @option.device ||= "/dev/sdh"
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      raise "Volume #{@argv.volid} does not exist" unless rvol.exists?(@argv.volid)
      raise "Volume #{@argv.volid} is already attached" if rvol.attached?(@argv.volid)
      raise "Instance #{@option.instance} does not exist" unless rinst.exists?(@option.instance)
      
      puts "Attaching #{@argv.volid} to #{@option.instance} on #{@option.device}"
      exit unless Annoy.are_you_sure?(:low)
      
      execute_action("Attach Failed") { 
        rvol.attach(@argv.volid, @option.instance, @option.device) 
      }

      vol = rvol.get(@argv.volid)
      puts
      puts @global.verbose > 0 ? vol.inspect : vol.to_s
    end
    
    def volumes_detach_valid?
      raise "You must supply a volume ID." unless @argv.volid
      true
    end
    
    def volumes_detach
      puts "Volumes".bright
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      raise "Volume #{@argv.volid} does not exist" unless rvol.exists?(@argv.volid)
      
      vol = rvol.get(@argv.volid)
      raise "Volume #{vol.awsid} is not attached" unless vol.attached?
      
      puts "Detaching #{vol.awsid} from #{vol.instid}"
      exit unless Annoy.are_you_sure?(:low)
      
      execute_action("Detach Failed") { rvol.detach(vol.awsid) }
      
      vol = rvol.get(vol.awsid)
      puts
      puts @global.verbose > 0 ? vol.inspect : vol.to_s
    end
    
    
    def volumes
      puts "Volumes".bright
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      volumes = rvol.list || []
      volumes.each do |vol|
        puts
        puts @global.verbose > 0 ? vol.inspect : vol.to_s
      end
      puts "No volumes" if volumes.empty?
    end
    
  end

end; end
end; end
