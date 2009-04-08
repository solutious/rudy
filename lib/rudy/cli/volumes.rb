

module Rudy
  module CLI
    class Volumes < Rudy::CLI::Base
      

      def destroy_volume_valid?
        raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid
        
        @rvol = Rudy::Volumes.new(:config => @config, :global => @global)
        
        @volume = @rvol.get(@argv.volid)
        
        raise "Volume #{@argv.volid} does not exist" unless @volume
        
        raise "Volume #{@argv.volid} is still in-use" if @volume.in_use?
        raise "Volume #{@argv.volid} is still attached" if @volume.attached?
        
        true
      end
      
      def destroy_volume
        puts "Destroy Volume".bright, $/
        
        puts "Destroying #{@volume.awsid}"
        exit unless Annoy.are_you_sure?(:medium)
        
        ret = @rvol.destroy(@volume.awsid)
        raise "Failed" unless ret
        
        vol = @rvol.get(@volume.awsid)
        
        puts vol.to_s
      end
      
      
      def volume_create_valid?
        raise "You must supply a volume size. See rudy volume -h" unless @option.size
        raise "You have no zone configured. Check #{RUDY_CONFIG_FILE}." unless @global.zone
        true
      end
      def volume_create
        puts "Create Volume".bright
        
        exit unless Annoy.are_you_sure?(:medium)
        
        rvol = Rudy::Volumes.new(:config => @config, :global => @global)
        vol = rvol.create(@option.size, @global.zone, @option.snapshot)
        
        puts vol.to_s
      end
      
      def volume_attach_valid?
        raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid
        raise "You must supply an instance ID. See rudy volume -h" unless @argv.instid
        
        @rvol = Rudy::Volumes.new(:config => @config, :global => @global)
        @rmach = Rudy::Machines.new(:config => @config, :global => @global)
        raise "Volume #{@argv.volid} does not exist" unless @rvol.exists?(@argv.volid)
        raise "Instance #{@argv.instid} does not exist" unless @rmach.exists?(@argv.instid)
        
        true
      end
      def volume_attach
        puts "Attach Volume".bright, $/
        
        @option.device ||= "/dev/sdh"
        
        puts "Attaching #{@argv.volid} to #{@argv.instid} on #{@option.device}"
        exit unless Annoy.are_you_sure?(:low)
        
        ret = @rvol.attach(@argv.volid, @argv.instid, @option.device)
        raise "Attach failed" unless ret
        volume = @rvol.get(@argv.volid)
        puts volume.to_s
      end
      
      def volume_detach_valid?
        raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid
        
        @rvol = Rudy::Volumes.new(:config => @config, :global => @global)
        
        @volume = @rvol.get(@argv.volid)
        
        raise "Volume #{@argv.volid} does not exist" unless @volume
        
        #raise "Volume #{@argv.volid} is in use" unless @volume.in_use?
        raise "Volume #{@argv.volid} is not attached" unless @volume.attached?
        
        true
      end
      def volume_detach
        puts "Detach Volume".bright, $/
        
        puts "Detaching #{@volume.awsid} from #{@volume.instid}"
        exit unless Annoy.are_you_sure?(:low)
        
        ret = @rvol.detach(@volume.awsid)
        raise "Detach failed" unless ret
        volume = @rvol.get(@volume.awsid)
        puts volume.to_s
      end
      
      
      def volume
        puts "Volumes".bright, $/
        
        rvol = Rudy::Volumes.new(:config => @config, :global => @global)
        volumes = rvol.list || []
        volumes.each do |volume|
          puts '-'*60
          puts volume.to_s
        end
        puts "No volumes" if volumes.empty?
      end
      
    end
  end
end

