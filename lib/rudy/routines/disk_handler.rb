

module Rudy::Routines
  class DiskHandler
    include Rudy::Huxtable    # @config, @global come from here
    
    
    # +machine+ is a Rudy::AWS::EC2::Instance object
    # +routines+ is a Hash config contain the disk routines.
    def execute(machine, routines)
      
      @logger.puts "Running DISK routines".bright
      
      
      unless routines
        @logger.puts "No #{action} disk routines."
        return
      end
      
      unless machine.awsid
        @logger.puts "Machine given has no instance ID. Skipping disk routines."
        return
      end
    
      unless machine.dns_name_public
        @logger.puts "Machine given has no DNS name: #{machine.awsid}. Skipping disk routines."
        return
      end
      
      # The order is important. We could be destroying and recreating
      # a disk on the same machine. 
      destroy(machine, routines.destroy) if routines.destroy
      mount(machine, routines.mount) if routines.mount
      restore(machine, routines.restore) if routines.restore
      create(machine, routines.create) if routines.create
    
    end
    
    
    def create(machine, disk_routine)
      
      disk_routine.each_pair do |path,props|
  
        begin 
          puts "Creating disk for #{path}"
          
          disk = Rudy::MetaData::Disk.new
          disk.path = path
          [:region, :zone, :environment, :role, :position].each do |n|
            disk.send("#{n}=", @global.send(n)) if @global.send(n)
          end
          [:device, :size].each do |n|
            disk.send("#{n}=", props[n]) if props.has_key?(n)
          end
      
                  
          puts "Creating volume... (#{disk.size}GB in #{@global.zone})".bright
          volume = @ec2.volumes.create(@global.zone, disk.size)
      
          puts "Attaching #{volume[:aws_id]} to #{machine.awsid}".bright
          @ec2.volumes.attach(machine.awsid, volume[:aws_id], disk.device)
          sleep 6
          
          puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
          ssh_command machine.dns_name_public, keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
          sleep 3
          
          puts "Mounting #{disk.device} to #{disk.path}".bright
          ssh_command machine.dns_name_public, keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
        
          puts "Creating disk metadata for #{disk.name}"
          disk.awsid = volume[:aws_id]
          Rudy::MetaData::Disk.save(@sdb, disk)
        
          sleep 1
        rescue => ex
          @logger.puts "There was an error creating #{path}: #{ex.message}".color(:red)
          @logger.puts ex.backtrace
          # NOTE: This isn't necessary right? B/c saving happens last so if there
          # is an exception, the disk metadata would never be saved. 
          #if disk
          #  puts "Removing metadata for #{disk.name}"
          #  Rudy::MetaData::Disk.destroy(@sdb, disk)
          #end
        end
        puts
      end
    end
    
    
    
    def destroy(machine, disk_routine)
      disk_paths = disk_routine.keys
      
      vols = @ec2.instances.volumes(machine.awsid) || []
      puts "No volumes to destroy for (#{machine.awsid})" if vols.empty?
      vols.each do |vol|
        disk = Rudy::MetaData::Disk.find_from_volume(@sdb, vol[:aws_id])
        if disk
          this_path = disk.path
        else
          puts "No disk metadata for volume #{vol[:aws_id]}. Going old school..."
          this_path = device_to_path(machine, vol[:aws_device])
        end
        
        if disk_paths.member?(this_path) 
        
          
          begin
            puts "Unmounting #{this_path}..."
            ssh_command machine.dns_name_public, keypairpath, @global.user, "umount #{this_path}"
            sleep 3
          rescue => ex
            puts "Error while unmounting #{this_path}: #{ex.message}"
            puts ex.backtrace if Drydock.debug?
            puts "We'll keep going..."
          end
          
          begin
            
            if @ec2.volumes.attached?(disk.awsid)
              puts "Detaching #{vol[:aws_id]}"
              @ec2.volumes.detach(vol[:aws_id])
              sleep 3 # TODO: replace with something like wait_for_machine
            end
            
            puts "Destroying #{this_path} (#{vol[:aws_id]})"
            if @ec2.volumes.available?(disk.awsid)
              @ec2.volumes.destroy(vol[:aws_id])
            else
              puts "Volume is still attached (maybe a web server of database is running?)"
            end
            
            if disk
              puts "Deleteing metadata for #{disk.name}"
              Rudy::MetaData::Disk.destroy(@sdb, disk)
            end
          
          rescue => ex
            puts "Error while detaching volume #{vol[:aws_id]}: #{ex.message}"
            puts ex.backtrace if Drydock.debug?
            puts "Continuing..."
          end
          
        end
        puts
        
      end
      
    end
    
    
    def mount(machine, disk_routine)
      disk_paths = disk_routine.keys 
      vols = @ec2.instances.volumes(machine.awsid) || []
      puts "No volumes to mount for (#{machine.awsid})" if vols.empty?
      vols.each do |vol|
        disk = Rudy::MetaData::Disk.find_from_volume(@sdb, vol[:aws_id])
        if disk
          this_path = disk.path
        else
          puts "No disk metadata for volume #{vol[:aws_id]}. Going old school..."
          this_path = device_to_path(machine, vol[:aws_device])
        end
        
        next unless disk_paths.member?(this_path)
        
        begin
          unless @ec2.instances.attached_volume?(machine.awsid, vol[:aws_device])
            puts "Attaching #{vol[:aws_id]} to #{machine.awsid}".bright
            @ec2.volumes.attach(machine.awsid, vol[:aws_id],vol[:aws_device])
            sleep 3
          end

          puts "Mounting #{this_path} to #{vol[:aws_device]}".bright
          ssh_command machine.dns_name_public, keypairpath, @global.user, "mkdir -p #{this_path} && mount -t ext3 #{vol[:aws_device]} #{this_path}"

          sleep 1
        rescue => ex
          puts "There was an error mounting #{this_path}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
        end
        puts 
      end
    end
    
    
    
    
    
    def restore(machine, disk_routine)
      
      disk_routine.each_pair do |path,props|
        from = props[:from] || "unknown"
        unless from.to_s == "backup"
          puts "Sorry! You can currently only restore from backup. Check your routines config."
          next
        end
        
        begin 
          puts "Restoring disk for #{path}"
          
          zon = props[:zone] || @global.zone
          env = props[:environment] || @global.environment
          rol = props[:role] || @global.role
          pos = props[:position] || @global.position
          puts "Looking for backup from #{zon}-#{env}-#{rol}-#{pos}"
          backup = find_most_recent_backup(zon, env, rol, pos, path)
          
          unless backup
            puts "No backups found"
            next
          end
          
          puts "Found: #{backup.name}".bright
          
          disk = Rudy::MetaData::Disk.new
          disk.path = path
          [:region, :zone, :environment, :role, :position].each do |n|
            disk.send("#{n}=", @global.send(n)) if @global.send(n)
          end
          
          disk.device = props[:device]
          size = (backup.size.to_i > props[:size].to_i) ? backup.size : props[:size]
          disk.size = size.to_i
          
          
          if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
            puts "The disk #{disk.name} already exists."
            puts "You probably need to define when to destroy the disk."
            puts "Skipping..."
            next
          end

          if @ec2.instances.attached_volume?(machine.awsid, disk.device)
            puts "Skipping disk for #{disk.path} (device #{disk.device} is in use)"
            next
          end

          # NOTE: It's important to use Caesars' hash syntax b/c the disk property
          # "size" conflicts with Hash#size which is what we'll get if there's no 
          # size defined. 
          unless disk.size.kind_of?(Integer)
            puts "Skipping disk for #{disk.path} (size not defined)"
            next
          end

          if disk.path.nil?
            puts "Skipping disk for #{disk.path} (no path defined)"
            next
          end

          unless disk.valid?
            puts "Skipping #{disk.name} (not enough info)"
            next
          end

          puts "Creating volume... (from #{backup.awsid})".bright
          volume = @ec2.volumes.create(@global.zone, disk.size, backup.awsid)

          puts "Attaching #{volume[:aws_id]} to #{machine.awsid}".bright
          @ec2.volumes.attach(machine.awsid, volume[:aws_id], disk.device)
          sleep 3

          puts "Mounting #{disk.device} to #{disk.path}".bright
          ssh_command machine.dns_name_public, keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"

          puts "Creating disk metadata for #{disk.name}"
          disk.awsid = volume[:aws_id]
          Rudy::MetaData::Disk.save(@sdb, disk)

          sleep 1
        rescue => ex
          puts "There was an error restoring #{path}: #{ex.message}"
          puts ex.backtrace if Drydock.debug?
          #if disk
          #  puts "Removing metadata for #{disk.name}"
          #  Rudy::MetaData::Disk.destroy(@sdb, disk)
          #end
        end
        puts
      end
    
    
    end
    
    
    
    def device_to_path(machine, device)
      # /dev/sdr            10321208    154232   9642688   2% /rilli/app
      dfoutput = ssh_command(machine.dns_name_public, keypairpath, @global.user, "df #{device} | tail -1").chomp
      dfvals = dfoutput.scan(/(#{device}).+\s(.+?)$/).flatten  # ["/dev/sdr", "/rilli/app"]
      dfvals.last
    end
    
  end
end