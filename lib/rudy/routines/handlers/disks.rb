
module Rudy::Routines::Handlers;
  module Disks
    include Rudy::Routines::Handlers::Base
    extend self
    
    ACTIONS = [:create, :destroy, :archive, :mount, :restore,
               :attach, :detach, :mount, :umount].freeze
    
    Rudy::Routines.add_handler :disks, self
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def disks?(routine)
      (routine.kind_of?(Hash) && routine.disks && 
      routine.disks.kind_of?(Hash) && !routine.disks.empty?) ? true : false
    end
    
    def paths(routine)
      return nil unless disks?(routine)
      routine.disks.values.collect { |d| d.keys }.flatten
    end
    
    
    def execute(type, routine, rset, lbox, argv=nil)
      original_user = rset.user
      rset.add_key user_keypairpath('root')
      rset.switch_user 'root'
      
      # We need to add mkfs since it's not enabled by default. 
      # We prepend the command with rudy_ so we can delete it. 
      Rye::Cmd.add_command(:rudy_mkfs, 'mkfs')
      
      routine.each_pair do |action, disks|
        unless respond_to?(action.to_sym)  
          Rudy::Huxtable.le %Q(DiskHelper: unknown action "#{action}")
          next
        end
        # A quick hack to take advantage of the threading in Rye::Set.
        # The action method does not run in the context of a Rye::Box
        # object so we need to send rset as an argument. 
        rset.batch do
          disks.each_pair do |path, props|
            # self contains the current instance of Rye::Box. 
            disk = Rudy::Disk.new(self.stash.position, path, props)
            Rudy::Routines::Handlers::Disks.send(action, self, disk)
          end
        end

      end
      
      Rye::Cmd.remove_command(:rudy_mkfs)
      
      rset.switch_user original_user
    end
    
    
    def create(rbox, disk)
      if disk.exists?
        puts "Disk found: #{disk.name}"
        disk.refresh!          
      end
      
      unless @@global.force
        raise Rudy::Disks::AlreadyAttached, disk.name if disk.volume_attached?
      end
      
      unless disk.volume_exists?
        msg = "Creating volume... "
        disk.create
        Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
          disk.volume_available?
        }
      end
      
      attach rbox, disk unless disk.volume_attached?
      format rbox, disk if disk.raw?
      mount rbox, disk unless disk.mounted?

      disk.save :replace
    end
    
    
    
    def detach(rbox, disk)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      
      umount rbox, disk if disk.mounted?
      raise Rudy::Disks::InUse, disk.name if disk.mounted?

      msg = "Detaching #{disk.volid}..."
      disk.volume_detach 
      Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
        disk.volume_available? 
      }

    end
    
    def attach(rbox, disk)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::AlreadyAttached, disk.name if disk.volume_attached?
      
      msg = "Attaching #{disk.volid} to #{rbox.stash.instid}... "
      disk.volume_attach(rbox.stash.instid)
      Rudy::Utils.waiter(2, 10, STDOUT, msg) { 
        disk.volume_attached?
      }

    end
    
    def mount(rbox, disk)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      attach rbox, disk unless disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
        raise Rudy::Disks::NotFormatted, disk.name if disk.raw?
        raise Rudy::Disks::AlreadyMounted, disk.name if disk.mounted?
      end
      
      rbox.mkdir(:p, disk.path)
      
      puts "Mounting at #{disk.path}... "
  
      rbox.mount(:t, disk.fstype, disk.device, disk.path) 
      disk.mounted = true
      disk.save :replace
      sleep 1
    end
    
    
    def umount(rbox, disk)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      raise Rudy::Disks::NotMounted, disk.name if !disk.mounted?
      
      puts "Unmounting #{disk.path}... "
      rbox.umount(disk.path)
      disk.mounted = false
      disk.save :replace
      sleep 2
    end
    alias_method :unmount, :umount
    
    def format(rbox, disk)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      attach rbox, disk unless disk.volume_attached?
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::AlreadyFormatted, disk.name if !disk.raw?
      end
      
      disk.fstype = 'ext3' if disk.fstype.nil? || disk.fstype.empty?
      
      puts "Creating #{disk.fstype} filesystem for #{disk.device}... "
      rbox.rudy_mkfs(:t, disk.fstype, :F, disk.device)
      disk.raw = false
      disk.save :replace
    end
    
    def destroy(rbox, disk)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
        
      umount rbox, disk if disk.mounted?
      detach rbox, disk if disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::InUse, disk.name if disk.volume_attached?
      end
      
      puts "Destroying #{disk.name}"
      disk.destroy
    end
    
    def archive(rbox, disk)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      
      back = disk.archive
      puts "Created backup: #{back.name}"
    end
    
    def restore(rbox, disk)
      
      if disk.exists?
        puts "Disk found: #{disk.name}"
        disk.refresh!       
      end
      
      unless @@global.force
        raise Rudy::Disks::AlreadyAttached, disk.name if disk.volume_attached?
      end
      
      latest_backup = disk.backups.last
      disk.size, disk.fstype = latest_backup.size, latest_backup.fstype
      
      puts "Backup found: #{latest_backup.name}"
      
      unless disk.volume_exists?
        msg = "Creating volume... "
        disk.create latest_backup.size, latest_backup.zone, latest_backup.snapid
        Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
          disk.volume_available?
        }
        
      end
      disk.raw = false
      
      attach rbox, disk unless disk.volume_attached?
      #format rbox, disk if disk.raw?
      mount rbox, disk unless disk.mounted?
      
      disk.save :replace

    end
    
    
  end
end
