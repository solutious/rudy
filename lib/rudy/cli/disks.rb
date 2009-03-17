

module Rudy
  module CLI
    class Disks < Rudy::CLI::Base

      def disk
        puts "Disks".bright
        opts = {}
        [:all, :path, :device, :size].each do |v| 
          opts[v] = @option.send(v) if @option.respond_to?(v)
        end
        rdisks = Rudy::Disks.new(:config => @config, :global => @global)
        list = rdisks.list(opts) || []
        #rbacks = Rudy::Backups.new(:config => @config, :global => @global)
        list.each do |disk|
          #backups = rbacks.list_by_disk(disk, 2)
          print_disk(disk, backups)
        end
      end
      def print_disk(disk, backups=[])
        puts '-'*60
        puts "Disk: #{disk.name.bright}"
        puts disk.to_s
        puts "#{backups.size} most recent backups:", backups.collect { |back| "#{back.nice_time} (#{back.awsid})" }
        puts
      end
      
      def create_disk_valid?
        raise "No filesystem path specified" unless @option.path
        raise "No size specified" unless @option.size
        raise "No device specified" unless @option.device
        #@instances = @ec2.instances.list(machine_group)
        #raise "There are no instances running in #{machine_group}" if !@instances || @instances.empty?
        true
      end
      
      def create_disk
        puts "Creating Disk".bright
        #exit unless Annoy.are_you_sure?(:low)
        opts = {}
        [:path, :device, :size, :group].each do |v| 
          opts[v] = @option.send(v) if @option.respond_to?(v)
        end
        opts[:id] = @option.awsid if @option.awsid
        opts[:id] &&= [opts[:id]].flatten
        
        @global.debug = true
        rdisks = Rudy::Disks.new(:config => @config, :global => @global)
        p rdisks.create(opts)
        #print_disk(disk)
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
        exit unless Annoy.are_you_sure?(:high)
        
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
        exit unless Annoy.are_you_sure?(:medium)
  
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
         exit unless Annoy.are_you_sure?(:high)
         
         machine = @instances.values.first

         execute_unattach_disk(@disk, machine)

         puts "Done!"
       end



      def execute_unattach_disk(disk, machine)
        begin
          
          if machine
            puts "Unmounting #{disk.path}...".bright
            ssh_command machine[:dns_name], keypairpath, global.user, "umount #{disk.path}"
            sleep 1
          end
          
          if @ec2.volumes.attached?(disk.awsid)
            puts "Unattaching #{disk.awsid}".bright
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
              puts "Destroying #{disk.path} (#{disk.awsid})".bright
              @ec2.volumes.destroy(disk.awsid)
            end
            
          end
          
        rescue => ex
          puts "Error while destroying volume #{disk.awsid}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
        ensure
          puts "Deleteing metadata for #{disk.name}".bright
          Rudy::MetaData::Disk.destroy(@sdb, disk)
        end
      end
      
      def execute_attach_disk(disk, machine)
        begin
          unless @ec2.instances.attached_volume?(machine[:aws_instance_id], disk.device)
            puts "Attaching #{disk.awsid} to #{machine[:aws_instance_id]}".bright
            @ec2.volumes.attach(machine[:aws_instance_id], disk.awsid, disk.device)
            sleep 3
          end
          
          if disk.raw_volume
            puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
            ssh_command machine[:dns_name], keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
            sleep 1
          end
          
          puts "Mounting #{disk.path} to #{disk.device}".bright
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

    



