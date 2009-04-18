

module Rudy; module Routines;

  class Shutdown < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      rdisk = Rudy::Disks.new
      routine = fetch_routine_config(:shutdown)

      rmach.destroy do |machine|
      #rmach.list do |machine|
        puts "Destroying #{machine.name}"
        
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "", nil) { 
          machine.update
          machine.dns_public? && Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        # Execute Disk Routines
        (routine.disks || {}).each_pair do |action, disks|
          next unless rdisk.respond_to?(action)  # create, copy, ...
          if action == :destroy
            disks.each_pair do |path, props|
              disk = Rudy::Disk.new(path, props[:size], props[:device], machine.position)
              disk = rdisk.get(disk.name)
              puts "Destroying #{disk.name}"

              if disk.mounted?
                print "Unmounting #{disk.path}... "
                rbox.umount(disk.path)
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
      end
    end

  end

end; end