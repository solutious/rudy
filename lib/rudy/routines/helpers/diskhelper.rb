

module Rudy; module Routines; 
  module DiskHelper
    include Rudy::Routines::HelperBase  # TODO: use execute_rbox_command
    extend self
    
    def disks?(routine)
      (routine.is_a?(Caesars::Hash) && routine.disks && 
      routine.disks.is_a?(Caesars::Hash) && !routine.disks.empty?) ? true : false
    end
    
    def paths(routine)
      return nil unless disks?(routine)
      routine.disks.values.collect { |d| d.keys }.flatten
    end
    
    def execute(routine, machine, rbox)
      return unless routine
      raise "Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      
      @machine = machine
      @rbox = rbox
      
      # We need to add mkfs since it's not enabled by default. 
      # We add it only to this instance we're using. 
      # We give it a funny name so we can delete it. 
      def @rbox.rudy_mkfs(*args); cmd('mkfs', args); end
      
      unless disks?(routine)
        STDERR.puts "[nothing to do]"
        return
      end

      modified = []
      routine.disks.each_pair do |action, disks|
        unless DiskHelper.respond_to?(action)  
          STDERR.puts %Q(DiskHelper: unknown action "#{action}")
          next
        end
        send(action, disks) # create, copy, destroy, ...
        modified << disks
      end
      
      # TODO: remove rudy_mkfs method
      
    end
    
    def create(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        disk = Rudy::Disk.new(path, props[:size], props[:device], @machine.position)
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
      
    def destroy(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        adisk = Rudy::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(adisk.name)
        if disk == nil
          puts "Not found: #{adisk.name}".color(:red)
          return
        end
        
        puts "Destroying #{disk.name}"

        if disk.mounted?
          print "Unmounting #{disk.path}..."
          execute_rbox_command { @rbox.umount(disk.path) }
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
end;end