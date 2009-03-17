

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

        ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
        raise "The volume #{@argv.volid} doesn't exist!" unless ec2.volumes.exists?(@argv.volid)
        raise "The volume #{@argv.volid} is already being deleted!" if ec2.volumes.deleting?(@argv.volid)
        
        exit unless Annoy.are_you_sure?(:high)
        
        rdisks = Rudy::Disks.new(:config => @config, :global => @global)
        disk = rdisks.find_from_volume(@argv.volid)
        
        if disk
          puts "The following disk metadata will also be destroyed:"
          puts disk.to_s
          exit unless Annoy.are_you_sure?(:high)
        end
        
        begin
          
          if ec2.volumes.attached?(@argv.volid)
            puts "Detaching #{@argv.volid}"
            ec2.volumes.detach(@argv.volid)
          
            Rudy.waiter(2, 30) do
              ec2.volumes.available?(@argv.volid)
            end
            puts
          end
          
          puts "Destroying #{@argv.volid}"
          ec2.volumes.destroy(@argv.volid)
          
          if disk
            puts "Deleteing metadata for #{disk.name}"
            rdisks.destroy(disk)
          end
          
        rescue => ex
          puts "Error while detaching volume #{id}: #{ex.message}"
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

