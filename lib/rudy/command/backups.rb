



module Rudy
  module Command
    class Backups < Rudy::Command::Base
      
      
      def backup
        criteria = [@global.zone]
        criteria += [@global.environment, @global.role] unless @option.all
        
        Rudy::MetaData::Backup.list(@sdb, *criteria).each do |backup|
          puts "%s (%s)" % [backup.name, backup.awsid]
        end
      end
      
      # Check for backups pointing to snapshots that don't exist. 
      def sync_backup
        unless argv.empty?
          puts "The disk you specified will be ignored."
          argv.clear
        end
        
        criteria = [@global.zone]
        criteria += [@global.environment, @global.role] unless @option.all
        
        puts "Looking for backup metadata with delinquent snapshots..."
        to_be_deleted = {} # snap-id => backup
        Rudy::MetaData::Backup.list(@sdb, *criteria).each do |backup|
          to_be_deleted[backup.awsid] = backup unless @ec2.snapshots.exists?(backup.awsid)
        end
        
        if to_be_deleted.empty?
          puts "All backups are in-sync with snapshots. Nothing to do."
          return
        end
        
        puts
        puts "These backup metadata will be deleted:"
        to_be_deleted.each do |snap_id, backup|
          puts "%s: %s" % [snap_id, backup.name]
        end
        
        puts
        are_you_sure?
        
        puts 
        puts "Deleting..."
        to_be_deleted.each do |snap_id, backup|
          print " -> #{backup.name}... "
          @sdb.destroy(RUDY_DOMAIN, backup.name)
          puts "done"
        end
        
        puts "Done!"
      end
      
      def destroy_backup_valid?
        raise "No backup specified" if argv.empty?
        exit unless are_you_sure?(5)
        true
      end
      
      def destroy_backup
        name = @argv.first
        puts "Destroying #{name}"
        begin
          backup = Rudy::MetaData::Backup.get(@sdb, name)
        rescue => ex
          puts "Error deleteing backup: #{ex.message}"
        end
        
        return unless backup
        
        begin
          puts " -> deleting snapshot..."
          @ec2.snapshots.destroy(backup.awsid)
        rescue => ex
          puts "Error deleting snapshot: #{ex.message}."
          puts "Continuing..."
        ensure
          puts " -> deleting metadata..."
          @sdb.destroy(RUDY_DOMAIN, name)
        end
        puts "Done."
      end
      
      def create_backup
        diskname = @argv.first
        
        machine = find_current_machine
        
        disks = Rudy::MetaData::Disk.list(@sdb, machine[:aws_availability_zone], @global.environment, @global.role, @global.position)
        raise "The machine #{machine_name} does not have any disk metadata" if disks.empty?
        
        puts "Machine: #{machine_name}"
        
        if @option.snapshot
          raise "You must supply a diskname when using an existing snapshot" unless diskname
          raise "The snapshot #{@option.snapshot} does not exist" unless @ec2.snapshots.exists?(@option.snapshot)
          disk = Rudy::MetaData::Disk.get(@sdb, diskname)
          
          raise "The disk #{diskname} does not exist" unless disk
          backup = Rudy::MetaData::Backup.new
          backup.awsid = @option.snapshot
          backup.time_stamp
            
          # Populate machine infos
          [:zone, :environment, :role, :position].each do |n|
            backup.send("#{n}=", @global.send(n)) if @global.send(n)
          end
        
          # Populate disk infos
          [:path, :size].each do |n|
            backup.send("#{n}=", disk.send(n)) if disk.send(n)
          end
          
          
          Rudy::MetaData::Backup.save(@sdb, backup)
          
          puts backup.name
          
        else
          volumes = @ec2.instances.volumes(machine[:aws_instance_id])
          raise "The machine #{machine_name} does not have any volumes attached." if volumes.empty?
          
          puts "#{disks.size} Disk(s) defined with #{volumes.size} Volume(s) running"
        
          volumes.each do |volume|
            print "Volume #{volume[:aws_id]}... "
            disk = Rudy::MetaData::Disk.from_volume(@sdb, volume[:aws_id])
            backup = Rudy::MetaData::Backup.new
          
            # TODO: Look for the disk based on the machine
            raise "No disk associated to volume #{volume[:aws_id]}" unless disk 
          
            backup.volume = volume[:aws_id]

            # Populate machine infos
            [:zone, :environment, :role, :position].each do |n|
              backup.send("#{n}=", @global.send(n)) if @global.send(n)
            end

            # Populate disk infos
            [:path, :size].each do |n|
              backup.send("#{n}=", disk.send(n)) if disk.send(n)
            end
            
            backup.time_stamp
            
            raise "There was a problem creating the backup metadata" unless backup.valid?
            
            snap = @ec2.snapshots.create(volume[:aws_id])
          
            if !snap || !snap.is_a?(Hash)
              puts "There was an unknown problem creating #{backup.name}. Continuing with the next volume..."
              next
            end
            
            backup.awsid = snap[:aws_id]

            Rudy::MetaData::Backup.save(@sdb, backup)

            puts backup.name
            
          end
        end          
      end
      
      
    end
  end
end