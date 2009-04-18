

module Rudy; module Routines; 
  module DiskHelper
    extend self
    
    def execute(routine, machine, rbox)
      raise "Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      
      @machine = machine
      @rbox = rbox
      
      (routine.disks || {}).each_pair do |action, disks|
        unless DiskHelper.respond_to?(action)  
          STDERR.puts %Q(DiskHelper: unknown action "#{action}")
          next
        end
        send(action, disks) # create, copy, destroy, ...
      end
    end
    
    def create(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        disk = Rudy::Disk.new(path, props[:size], props[:device], @machine.position)
        #disk = rdisk.get(disk.name)
        puts "Creating #{disk.name} "
        
        print "Creating volume... "
        disk.create
        Rudy::Utils.waiter(2, 60, STDOUT, "done", nil) { 
          disk.available?
        }
        
        print "Attaching #{disk.awsid} to #{@machine.awsid}... "
        disk.attach(@machine.awsid)
        Rudy::Utils.waiter(2, 60, STDOUT, "done", nil) { 
          disk.attached?
        }
        
        # The device needs some time. 
        # Otherwise mkfs returns:
        # "No such file or directory while trying to determine filesystem size"
        sleep 2 
        
        print "Creating ext3 filesystem for #{disk.device}... "
        @rbox.mkfs(:t, "ext3", :F, disk.device)
        @rbox.mkdir(:p, disk.path)
        puts "done"
        
        print "Mounting at #{disk.path}... "
        
        @rbox.mount(:t, 'ext3', disk.device, disk.path)
        disk.mounted = true
        disk.save
        puts "done"
        
      end
    end
      
    def destroy(disks)
      rdisk = Rudy::Disks.new
      
      disks.each_pair do |path, props|
        disk = Rudy::Disk.new(path, props[:size], props[:device], @machine.position)
        disk = rdisk.get(disk.name)
        puts "Destroying #{disk.name}"

        if disk.mounted?
          print "Unmounting #{disk.path}... "
          @rbox.umount(disk.path)
          sleep 0.5
          puts "done"
        end
        
        if disk.attached?
          print "Detaching #{disk.awsid}... "
          disk.detach 
          Rudy::Utils.waiter(2, 60, STDOUT, 'done', nil) { 
            disk.available? 
          }
          sleep 0.5
        end
        
        print "Destroying metadata... "
        disk.destroy
        puts "done"
        
      end
    end
      
  end
end;end