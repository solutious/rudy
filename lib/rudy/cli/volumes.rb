

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
            
        @argv.volid.each do |volid|
          begin
            ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
            raise "The volume #{volid} doesn't exist!" unless ec2.volumes.exists?(volid)
            raise "The volume #{volid} is already being deleted!" if ec2.volumes.deleting?(volid)
        
        
            rdisks = Rudy::Disks.new(:config => @config, :global => @global)
            disk = rdisks.find_from_volume(volid)
        
            if disk
              puts "There is a disk associated to this volume:".color(:blue)
              puts disk.name.color(:blue)
              puts "You must use: rudy disks -D #{disk.name}".color(:blue).bright
              return
            end
        
            volumes = Rudy::Volumes.new(:config => @config, :global => @global)
            volumes.destroy(volid)
            
          rescue => ex
            puts ex.message
            puts ex.backtrace if Drydock.debug?
          end
        end
      end
      
      
      def volume_create_valid?
        volume_valid?
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
      
      
      def volume_valid?
        raise "No AWS access keys configured" unless @global.accesskey && @global.secretkey
        true
      end
      def volume
        puts "Volumes".bright, $/
        # TODO: display by state
        @ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey) 
        volumes = @ec2.volumes.list
        volumes.each do |volume|
          puts '-'*60
          puts volume.to_s
        end
      end
      
    end
  end
end

