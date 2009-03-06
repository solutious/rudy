

module Rudy
  module Command
    class Volumes < Rudy::Command::Base
      
      def destroy_volumes_valid?        
        id = @argv.first
        raise "No volume ID provided" unless id
        raise "I will not help you destroy production!" if @global.environment == "prod"
        raise "The volume #{id} doesn't exist!" unless @ec2.volumes.exists?(id)
        exit unless are_you_sure? 4
      end
        
      def destroy_volumes
        id = @argv.first
        disk = Rudy::MetaData::Disk.from_volume(@sdb, id)
        puts "Destroying #{id}!"
        @ec2.volumes.destroy id
        
        disk.awsid = nil if disk
        
        Rudy::MetaData::Disk.save(@sdb, disk)
        
      end
      
      def volumes
        machines = {}
        volumes = @ec2.volumes.list
        @ec2.volumes.list.each do |volume|
          machine = @ec2.instances.get(volume[:aws_instance_id])
          machines[ volume[:aws_instance_id] ] ||= {
            :machine => machine,
            :volumes => []
          }
          machines[ volume[:aws_instance_id] ][:volumes] << volume
        end
        
        machines.each_pair do |instance_id, hash|
          machine = hash[:machine]
          env = (machine[:aws_groups]) ? machine[:aws_groups] : "Not-attached"
          puts "Environment: #{env}"
          hash[:volumes].each do |vol|
            disk = Rudy::MetaData::Disk.from_volume(@sdb, vol[:aws_id])
            print_volume(vol, disk)
          end
        end
      end
      
    end
  end
end

