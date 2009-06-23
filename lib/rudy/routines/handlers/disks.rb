
module Rudy; module Routines; module Handlers;
  module Disks
    include Rudy::Routines::Handlers::Base
    extend self
    
    Rudy::Routines.add_handler :disks, self
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def disks?(routine)
      (routine.is_a?(Caesars::Hash) && routine.disks && 
      routine.disks.is_a?(Caesars::Hash) && !routine.disks.empty?) ? true : false
    end
    
    def paths(routine)
      return nil unless disks?(routine)
      routine.disks.values.collect { |d| d.keys }.flatten
    end
    
    def execute(type, routine, rset, lbox, argv=nil)
      
      # We need to add mkfs since it's not enabled by default. 
      # We prepend the command with rudy_ so we can delete it. 
      Rye::Cmd.add_command(:rudy_mkfs) do |*args|
        cmd('mkfs', args)
      end
      
      modified = []
      routine.each_pair do |action, disks|
        unless respond_to?(action.to_sym)  
          Rudy::Huxtable.le %Q(DiskHelper: unknown action "#{action}")
          next
        end
        p action
        #send(action, disks) # create, copy, destroy, ...
        #modified << disks
      end
      
      Rye::Cmd.remove_command(:rudy_mkfs)
    end
    
    def snapshot(disks)
      rdisk = Rudy::Disks.new
      rback = Rudy::Backups.new
      
      disks.each_pair do |path, props|
        adisk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(adisk.name)
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        back = disk.backup
        puts "Created backup: #{back.name}"
      end
    end
    
    def restore(disks)
      rdisk = Rudy::Disks.new
      rback = Rudy::Backups.new
      
      disks.each_pair do |path, props|
        disk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        
        olddisk = rdisk.get(disk.name)
        back = nil
        if olddisk && olddisk.exists?
          olddisk.update
          puts "Disk found: #{olddisk.name}. Skipping...".color(:red)
          return
        else
          disk.fstype = props[:fstype] || 'ext3'
          more = [:environment, props[:environment]] if props[:environment]
          more += [:role, props[:role]] if props[:role]
          back = (rback.list(more, nil) || []).first
          raise "No backup found" unless back
          puts "Found backup #{back.name} "
        end
        
        unless disk.exists? # Checks the EBS volume
          msg = "Creating volume from snapshot (#{back.awsid})... "
          disk.create(back.size, @@global.zone, back.awsid)
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available?
          }
        end
        
        msg = "Attaching #{disk.awsid} to #{@machine.awsid}... "
        disk.attach(@machine.awsid)
        Rudy::Utils.waiter(2, 10, STDOUT, msg) { 
          disk.attached?
        }
        
        sleep 2
        
        begin
          @rbox.mkdir(:p, disk.path)
          
          print "Mounting at #{disk.path}... "
      
          ret = @rbox.mount(:t, disk.fstype, disk.device, disk.path) 
          print_response ret
          if ret.exit_code > 0
            STDERR.puts "Error creating disk".color(:red)
            return
          else
            puts "done"
          end
          disk.mounted = true
          disk.save
          
        rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
          STDERR.puts "Error creating disk".color(:red)
          STDERR.puts ex.message.color(:red)
         rescue Rye::CommandNotFound => ex
          puts "  CommandNotFound: #{ex.message}".color(:red)
          
        rescue
          STDERR.puts "Error creating disk" .color(:red)
          Rudy::Utils.bug
        end
        
      end
    end
    
    
    def create(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        disk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        olddisk = rdisk.get(disk.name)
        if olddisk && olddisk.exists?
          olddisk.update
          puts "Disk found: #{olddisk.name}"
          if olddisk.attached?
            puts "In use. Skipping...".color(:red)
            return
          else
            disk = olddisk
          end
        else
          puts "Creating #{disk.name} "
          disk.fstype = props[:fstype] || 'ext3'
        end
        
        unless disk.exists? # Checks the EBS volume
          msg = "Creating volume... "
          disk.create
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available?
          }
        end
        
        msg = "Attaching #{disk.awsid} to #{@machine.awsid}... "
        disk.attach(@machine.awsid)
        Rudy::Utils.waiter(2, 10, STDOUT, msg) { 
          disk.attached?
        }
        
        # The device needs some time. 
        # Otherwise mkfs returns:
        # "No such file or directory while trying to determine filesystem size"
        sleep 2 
        
        # TODO: Cleanup. See ScriptHelper
        begin
          if disk.raw == true
            print "Creating #{disk.fstype} filesystem for #{disk.device}... "
            @rbox.rudy_mkfs(:t, disk.fstype, :F, disk.device)
            disk.raw = false
            disk.save
            puts "done"
          end
          
          @rbox.mkdir(:p, disk.path)
          
          print "Mounting at #{disk.path}... "
      
          ret = @rbox.mount(:t, disk.fstype, disk.device, disk.path) 
          print_response ret
          if ret.exit_code > 0
            STDERR.puts "Error creating disk".color(:red)
            return
          else
            puts "done"
          end
          disk.mounted = true
          disk.save
          
        rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
          STDERR.puts "Error creating disk".color(:red)
          STDERR.puts ex.message.color(:red)
         rescue Rye::CommandNotFound => ex
          puts "  CommandNotFound: #{ex.message}".color(:red)
          
        rescue
          STDERR.puts "Error creating disk" .color(:red)
          Rudy::Utils.bug
        end
 
      end
    end
    
    
    
    
    def attach(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        disk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        olddisk = rdisk.get(disk.name)
        if olddisk && olddisk.exists?
          disk.update
          puts "Disk found: #{olddisk.name}"
          if disk.attached?
            puts "In use. Skipping...".color(:red)
            return
          else
            disk = olddisk
          end
        else
          puts "Creating #{disk.name} "
        end
        p disk
        p [disk.exists?, disk.available?, olddisk.exists?, olddisk.available?]
        disk.save
        
        unless disk.exists? # Checks the EBS volume
          msg = "Creating volume... "
          disk.create
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available?
          }
        end
        
        unless disk.attached?
          msg = "Attaching #{disk.awsid} to #{@machine.awsid}... "
          disk.attach(@machine.awsid)
          Rudy::Utils.waiter(2, 10, STDOUT, msg) { 
            disk.attached?
          }
        end
      end
    end
    
    def detach(disks, destroy=false)
      rdisk = Rudy::Disks.new
      disks.each_pair do |path, props|
        adisk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get adisk.name
        
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        
        if disk.attached?
          msg = "Detaching #{disk.awsid}..."
          disk.detach 
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available? 
          }
        end
        
        if destroy 
          puts "Destroying volume and metadata... "
          disk.destroy
        end
        
      end
    end
    
    def mount(disks)
      rdisk = Rudy::Disks.new
      disks.each_pair do |path, props|
        adisk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(adisk.name)
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        
        unless disk.attached?
          msg = "Attaching #{disk.awsid} to #{@machine.awsid}... "
          disk.attach(@machine.awsid)
          Rudy::Utils.waiter(2, 10, STDOUT, msg) { 
            disk.attached?
          }
        
          sleep 2
        end
        
        begin
          @rbox.mkdir(:p, disk.path)
          
          print "Mounting at #{disk.path}... "
      
          ret = @rbox.mount(:t, disk.fstype, disk.device, disk.path) 
          print_response ret
          if ret.exit_code > 0
            STDERR.puts "Error creating disk".color(:red)
            return
          else
            puts "done"
          end
          disk.mounted = true
          disk.save
          
        rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
          STDERR.puts "Error creating disk".color(:red)
          STDERR.puts ex.message.color(:red)
         rescue Rye::CommandNotFound => ex
          puts "  CommandNotFound: #{ex.message}".color(:red)
          
        rescue
          STDERR.puts "Error creating disk" .color(:red)
          Rudy::Utils.bug
        end
        
      end
    end
    
    
    def umount(disks)
      rdisk = Rudy::Disks.new
      disks.each_pair do |path, props|
        adisk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(adisk.name)
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        
        if disk.mounted?
          print "Unmounting #{disk.path}..."
          trap_rbox_errors { @rbox.umount(disk.path) }
          puts " done"
          sleep 0.5
        end
        
        sleep 2
        
        if disk.attached?
          msg = "Detaching #{disk.awsid}..."
          disk.detach 
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available? 
          }
          sleep 0.5
        end
        
        
      end
    end
    alias_method :unmount, :umount
    
    def destroy(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        adisk = Rudy::MetaData::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(adisk.name)
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        
        puts "Destroying #{disk.name}"

        if disk.mounted?
          print "Unmounting #{disk.path}..."
          trap_rbox_errors { @rbox.umount(disk.path) }
          puts " done"
          sleep 0.5
        end
        
        if disk.attached?
          msg = "Detaching #{disk.awsid}..."
          disk.detach 
          Rudy::Utils.waiter(2, 60, STDOUT, msg) { 
            disk.available? 
          }
          sleep 0.5
        end
        
        puts "Destroying volume and metadata... "
        disk.destroy
        
      end
    end
    
  end
end; end; end