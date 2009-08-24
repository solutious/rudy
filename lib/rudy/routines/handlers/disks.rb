
module Rudy::Routines::Handlers;
  module Disks
    include Rudy::Routines::Handlers::Base
    extend self
    
    ACTIONS = [:create, :destroy, :archive, :mount, :restore,
               :attach, :detach, :mount, :umount, :fstype].freeze
    
    Rudy::Routines.add_handler :disks, self
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def any?(routine)
      (routine.kind_of?(Hash) && routine.disks && 
      routine.disks.kind_of?(Hash) && !routine.disks.empty?) ? true : false
    end
    
    # Create mount?, create?, umount? etc... methods
    ACTIONS.each do |action|
      define_method "#{action}?" do |routine|
        return false unless any? routine
        routine.disks.member? action
      end
    end
    
    def paths(routine)
      return nil unless disks?(routine)
      routine.disks.values.collect { |d| d.keys }.flatten
    end
    
    
    def execute(type, routine, rset, lbox, argv=nil)
      original_user = rset.user
      rset.add_key user_keypairpath(current_machine_user)
      rset.switch_user current_machine_user
      
      # We need to add mkfs since it's not enabled by default. 
      # We prepend the command with rudy_ so we can delete it. 
      Rye::Cmd.add_command(:rudy_rm, 'rm')
      Rye::Cmd.add_command(:rudy_mkfs, 'mkfs')
      Rye::Cmd.add_command(:rudy_blkid, 'blkid')
      Rye::Cmd.add_command(:rudy_format, 'C:/windows/system32/format.com')
      Rye::Cmd.add_command(:rudy_diskpart, 'C:/windows/system32/diskpart.exe')
      
      routine.each_pair do |action, disks|
        unless respond_to?(action.to_sym)  
          Rudy::Huxtable.le %Q(DiskHelper: unknown action "#{action}")
          next
        end
        # A quick hack to take advantage of the threading in Rye::Set.
        # The action method does not run in the context of a Rye::Box
        # object so we need to send rset as an argument. 
        rset.batch do
          # Windows EC2 instances have 2 disks by default (C: and D:)
          index = Rudy::Huxtable.current_machine_os.to_s == 'windows' ? 2 : 0
          disks.each_pair do |path, props|
            # self contains the current instance of Rye::Box. 
            disk = Rudy::Disk.new(self.stash.position, path, props)
            Rudy::Routines::Handlers::Disks.send(action, self, disk, index)
            index += 1
          end
        end

      end
      
      Rye::Cmd.remove_command(:rudy_rm)
      Rye::Cmd.remove_command(:rudy_mkfs)
      Rye::Cmd.remove_command(:rudy_blkid)
      Rye::Cmd.remove_command(:rudy_format)
      Rye::Cmd.remove_command(:rudy_diskpart)
      
      rset.switch_user original_user
    end
    
    def fstype(rbox, disk, index)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      p rbox.rudy_blkid :s, 'TYPE', :o, 'value', disk.device
      
    end
    
    
    def create(rbox, disk, index)
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
      
      attach rbox, disk, index unless disk.volume_attached?
      format rbox, disk, index if disk.raw?
      mount rbox, disk, index unless disk.mounted?

      disk.save :replace
    end
    
    
    
    def detach(rbox, disk, index)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name unless disk.volume_attached?
      
      umount rbox, disk, index if disk.mounted?
      raise Rudy::Disks::InUse, disk.name if disk.mounted?

      msg = "Detaching #{disk.volid}..."
      disk.volume_detach 
      Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
        disk.volume_available? 
      }

    end
    
    def attach(rbox, disk, index)
      
      unless disk.volume_exists?
        msg = "Creating volume... "
        disk.create
        Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
          disk.volume_available?
        }
      end
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::AlreadyAttached, disk.name if disk.volume_attached?
      
      msg = "Attaching #{disk.volid} to #{rbox.stash.instid}... "
      disk.volume_attach(rbox.stash.instid)
      Rudy::Utils.waiter(3, 30, STDOUT, msg) { 
        disk.volume_attached?
      }

    end
    
    def mount(rbox, disk, index)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      if rbox.stash.windows?
        Rudy::Huxtable.li "Skipping for Windows"
        return 
      end
      
      attach rbox, disk unless disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
        raise Rudy::Disks::NotFormatted, disk.name if disk.raw?
        raise Rudy::Disks::AlreadyMounted, disk.name if disk.mounted?
      end
      
      puts "Mounting at #{disk.path}... "
      
      
      rbox.mkdir(:p, disk.path)
      rbox.mount(:t, disk.fstype, disk.device, disk.path) 
      disk.mounted = true
      disk.save :replace
      sleep 1

    end
    
    
    def umount(rbox, disk, index)
      
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      if @@global.force
        raise Rudy::Disks::NotMounted, disk.name if !disk.mounted?
      end
      
      puts "Unmounting #{disk.path}... "
      
      unless rbox.stash.windows?
        rbox.umount(disk.path)
      end
      
      disk.mounted = false
      disk.save :replace
      sleep 2
      
    end
    alias_method :unmount, :umount
    
    def format(rbox, disk, index)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      attach rbox, disk unless disk.volume_attached?
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::AlreadyFormatted, disk.name if !disk.raw?
      end
      
      if disk.fstype.nil? || disk.fstype.empty?
        disk.fstype = rbox.stash.default_fstype
      end
      
      print "Creating #{disk.fstype} filesystem for #{disk.path}... "
      if rbox.stash.windows?
        puts "(index: #{index})"
        windows_diskpart_partition rbox, disk, index
        disk.mounted = true
      else
        puts $/
        rbox.rudy_mkfs(:t, disk.fstype, :F, disk.device)
      end
      
      disk.raw = false
      disk.save :replace
    end
    
    def destroy(rbox, disk, index)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
        
      umount rbox,disk,index if disk.mounted? && !rbox.stash.windows?
      detach rbox,disk,index if disk.volume_attached?
      
      unless @@global.force
        raise Rudy::Disks::InUse, disk.name if disk.volume_attached?
      end
      
      puts "Destroying #{disk.name}"
      disk.destroy
    end
    
    def archive(rbox, disk, index)
      raise Rudy::Metadata::UnknownObject, disk.name unless disk.exists?
      disk.refresh!
      
      raise Rudy::Disks::NotAttached, disk.name if !disk.volume_attached?
      
      back = disk.archive
      puts "Created backup: #{back.name}"
    end
    
    def restore(rbox, disk, index)

      if disk.exists?
        puts "Disk found: #{disk.name}"
        disk.refresh!       
      end
      
      unless @@global.force
        raise Rudy::Disks::AlreadyAttached, disk.name if disk.volume_attached?
      end
      
      latest_backup = disk.backups.last
      
      if latest_backup.fstype.nil? || latest_backup.fstype.empty?
        latest_backup.fstype = rbox.stash.default_fstype
      end
      
      disk.size, disk.fstype = latest_backup.size, latest_backup.fstype
      
      puts "Backup found: #{latest_backup.name}"
      
      unless disk.volume_exists?
        msg = "Creating volume... "
        disk.create latest_backup.size, latest_backup.zone, latest_backup.snapid
        Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
          disk.volume_available?
        }
        disk.raw = false
        disk.save :replace  
      end
      
      attach rbox, disk, index unless disk.volume_attached?
      mount rbox, disk, index unless disk.mounted?
      
      disk.save :replace

    end
    
    
    private
    
    def windows_diskpart_partition(rbox, disk, disk_num)
      rbox.quietly { rudy_rm :f, 'diskpart-script' }
      rbox.file_append 'diskpart-script', %Q{
      select disk #{disk_num}
      clean
      create partition primary
      select partition 1
      active
      assign letter=#{disk.path.tr(':/', '')}
      exit}
      rbox.rudy_diskpart '/s', 'diskpart-script'
      rbox.quietly { rudy_rm :f, 'diskpart-script' }
      rbox.rudy_format disk.path, '/V:RUDY', "/FS:#{disk.fstype}", '/Q', '/Y'
    end
    
    
  end
end
