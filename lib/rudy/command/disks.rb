

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
        @instances = @ec2.instances.list(machine_group)
        raise "There are no instances running in #{machine_group}" if !@instances || @instances.empty?
        true
      end
      
      def create_disk
        puts "Creating #{@option.path} for #{machine_group}"
        switch_user("root")
        exit unless are_you_sure?(2) 
        machine = @instances.values.first # NOTE: DANGER! Should handle position.
        
        disk = Rudy::MetaData::Disk.new
        [:region, :zone, :environment, :role, :position].each do |n|
          disk.send("#{n}=", @global.send(n)) if @global.send(n)
        end
        [:path, :device, :size].each do |n|
          disk.send("#{n}=", @option.send(n)) if @option.send(n)
        end
        
        raise "Not enough info was provided to define a disk (#{disk.name})" unless disk.valid?
        raise "The device #{disk.device} is already in use on that machine" if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
        # TODO: Check disk path
        puts "Creating disk metadata for #{disk.name}"
        
        
        
        puts "Creating volume... (#{disk.size}GB in #{@global.zone})"
        volume = @ec2.volumes.create(@global.zone, disk.size)
        sleep 3
        
        disk.awsid = volume[:aws_id]
        disk.raw_volume = true    # This value is not saved. 
        Rudy::MetaData::Disk.save(@sdb, disk)
        
        execute_attach_disk(disk, machine)
        
        print_disk(disk)
      end
      
      
      def destroy_disk_valid?
        raise "No disk specified" if argv.empty?
        
        if @argv.diskname =~ /^disk-/          
          @disk = Rudy::MetaData::Disk.get(@sdb, @argv.diskname)
        else
          disk = Rudy::MetaData::Disk.new
          [:zone, :environment, :role, :position].each do |n|
            disk.send("#{n}=", @global.send(n)) if @global.send(n)
          end
          disk.path = @argv.diskname
          @disk = Rudy::MetaData::Disk.get(@sdb, disk.name)
        end

        raise "No such disk: #{@argv.diskname}" unless @disk
        raise "The disk is in another machine environment" unless @global.environment.to_s == @disk.environment.to_s
        raise "The disk is in another machine role" unless @global.role.to_s == @disk.role.to_s
        @instances = @ec2.instances.list(machine_group)
        true
      end
      
      def destroy_disk
        puts "Destroying #{@disk.name} and #{@disk.awsid}"
        switch_user("root")
        exit unless are_you_sure?(5)
        
        machine = @instances.values.first # NOTE: DANGER! Should handle position. 
        
        execute_unattach_disk(@disk, machine)
        execute_destroy_disk(@disk, machine)
        
        puts "Done."
      end

      def attach_disk_valid?
        destroy_disk_valid?
        raise "There are no instances running in #{machine_group}" if !@instances || @instances.empty?
        true
      end
      
      def attach_disk
        puts "Attaching #{name}"
        switch_user("root")
        are_you_sure?(4)
  
        machine = @instances.values.first  # AK! Assumes single machine
        
        execute_attach_disk(@disk, machine)

        puts
        ssh_command machine[:dns_name], keypairpath, @global.user, "df -h" # Display current mounts
        puts 

        puts "Done!"
      end




       def unattach_disk_valid?
         destroy_disk_valid?
         true
       end

       def unattach_disk
         puts "Unattaching #{@disk.name} from #{machine_group}"
         switch_user("root")
         are_you_sure?(4)
         
         machine = @instances.values.first

         execute_unattach_disk(@disk, machine)

         puts "Done!"
       end



      def execute_unattach_disk(disk, machine)
        begin
          
          if machine
            puts "Unmounting #{disk.path}...".att(:bright)
            ssh_command machine[:dns_name], keypairpath, global.user, "umount #{disk.path}"
            sleep 1
          end
          
          if @ec2.volumes.attached?(disk.awsid)
            puts "Unattaching #{disk.awsid}".att(:bright)
            @ec2.volumes.detach(disk.awsid)
            sleep 5
          end
          
        rescue => ex
          puts "Error while unattaching volume #{disk.awsid}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
        end
      end
      
      def execute_destroy_disk(disk, machine)
        begin
          
          if disk
            
            if disk.awsid && @ec2.volumes.available?(disk.awsid)
              puts "Destroying #{disk.path} (#{disk.awsid})".att(:bright)
              @ec2.volumes.destroy(disk.awsid)
            end
            
            puts "Deleteing metadata for #{disk.name}".att(:bright)
            Rudy::MetaData::Disk.destroy(@sdb, disk)
          end
          
        rescue => ex
          puts "Error while destroying volume #{disk.awsid}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
        end
      end
      
      def execute_attach_disk(disk, machine)
        begin
          unless @ec2.instances.attached_volume?(machine[:aws_instance_id], disk.device)
            puts "Attaching #{disk.awsid} to #{machine[:aws_instance_id]}".att(:bright)
            @ec2.volumes.attach(machine[:aws_instance_id], disk.awsid, disk.device)
            sleep 3
          end
          
          if disk.raw_volume
            puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".att(:bright)
            ssh_command machine[:dns_name], keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
            sleep 1
          end
          
          puts "Mounting #{disk.path} to #{disk.device}".att(:bright)
          ssh_command machine[:dns_name], keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"

          sleep 1
        rescue => ex
          puts "There was an error attaching #{disk.name}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
        end
      end
      
    end
  end
end


__END__

    



