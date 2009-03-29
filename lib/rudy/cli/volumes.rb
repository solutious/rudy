

module Rudy
  module CLI
    class Volumes < Rudy::CLI::Base
      
      def destroy_volume_valid?  
        raise "No volume ID provided" unless @argv.volid
        raise "I will not help you destroy production!" if @global.environment =~ /^prod/
        true
      end
      def destroy_volume
        puts "Destroy Volume".bright
        @argv.volid &&= [@argv.volid].flatten
        
        exit unless Annoy.are_you_sure?(:low)
        
        
      end
      
      
      def volume_create_valid?
        raise "You must supply a volume size. See rudy volume -h" unless @option.size
        raise "You have no zone configured. Check #{RUDY_CONFIG_FILE}." unless @global.zone
        true
      end
      def volume_create
        puts "Create Volume".bright
        ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
        vol = ec2.volumes.create(@global.zone, @option.size, @option.snapshot)
        Rudy.bug('hnic721') unless vol
        puts vol.to_s
      end
      
      
      def volume
        puts "Volumes".bright, $/
        # TODO: display by state
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

