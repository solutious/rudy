

module Rudy
  module Command
    class Disks < Rudy::Command::Base
      
      def disk
        criteria = [@global.zone]
        criteria += [@global.environment, @global.role] unless @option.all
        Rudy::MetaData::Disk.list(@sdb, *criteria).each do |disk|
          backups = Rudy::MetaData::Backup.for_disk(@sdb, disk, 2)
          print_disk(disk, backups)
        end
      end

      def create_disk_valid?
        raise "No filesystem path specified" unless @option.path
        raise "No size specified" unless @option.size
        true
      end
      
      def create_disk
        disk = Rudy::MetaData::Disk.new
        [:environment, :role, :position, :path, :device, :size].each do |n|
          disk.send("#{n}=", @option.send(n)) if @option.send(n)
        end
        
        raise "Not enough info was provided to define a disk (#{disk.name})" unless disk.valid?
        raise "The device #{disk.device} is already in use on that machine" if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
        puts "Creating disk metadata for #{disk.name}"
        
        Rudy::MetaData::Disk.save(@sdb, disk)
        
        print_disks
      end
      
      

      def unattach_disk_valid?
        raise "No disk specified" if argv.empty?
        exit unless are_you_sure?(4)
        true
      end
      
      def unattach_disk
        name = argv.first
        puts "Looking for #{name}"
        disk = Rudy::MetaData::Disk.get(@sdb, name)
        instances = @ec2.instances.list(machine_group)
        @global.user = "root"
        check_keys
        raise "That is not a valid disk" unless disk
        raise "There are no instances running in #{machine_group}" if !instances || instances.empty?
        raise "The disk has no attached volume " unless disk.awsid
        
        machine = instances.values.first
        
        puts "Unmounting #{disk.path}..."
        ssh_command machine[:dns_name], keypairpath, @global.user, "umount #{disk.path}"
        sleep 1
        
        puts "Detaching #{disk.awsid}"
        @ec2.volumes.detach(disk.awsid)
        
        Rudy::MetaData::Backup.for_disk(@sdb, disk, 2)
        
        puts "Done!"
      end
      
      def attach_disk_valid?
        raise "No disk specified" if argv.empty?
        true
      end
        
      def attach_disk
        name = @argv.first
        puts "Looking for #{name}"
        disk = Rudy::MetaData::Disk.get(@sdb, name)
        instances = @ec2.instances.list(machine_group)
        raise "There are no instances running in #{machine_group}" if !instances || instances.empty?
        instance_id = instances.keys.first # <--- TODO: This is bad!
        machine = instances.values.first
        
        do_dirty_disk_volume_deeds(disk, machine)
        
        
        puts
        ssh_command machine[:dns_name], keypairpath, @global.user, "df -h" # Display current mounts
        puts 
        
        puts "Done!"
      end
      
      
      def destroy_disk_valid?
        raise "No disk specified" if argv.empty?
        exit unless are_you_sure?(5)
        true
      end
      
      def destroy_disk
        name = @argv.first
        puts "Destroying #{name}"
        @sdb.destroy(RUDY_DOMAIN, name)
        puts "Done."
      end

    end
  end
end




