

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      rdisk = Rudy::Disks.new
      routine = fetch_routine_config(:startup)

      rmach.create do |machine|
      #rmach.list do |machine|
        puts 'before wait'
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "It's up!", nil) { 
          machine.update
          machine.dns_public? && Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        puts 'after wait'
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        # Execute Disk Routines
        (routine.disks || {}).each_pair do |action, disks|
          next unless rdisk.respond_to?(action)  # create, copy, ...
          if action == :create
            disks.each_pair do |path, props|
              disk = Rudy::Disk.new(path, props[:size], props[:device], machine.position)
              #disk = rdisk.get(disk.name)
              puts "Creating #{disk.name} "
              
              print "Creating volume... "
              disk.create
              Rudy::Utils.waiter(2, 60, STDOUT, "done", nil) { 
                disk.available?
              }
              
              print "Attaching #{disk.awsid} to #{machine.awsid}... "
              disk.attach(machine.awsid)
              Rudy::Utils.waiter(2, 60, STDOUT, "done", nil) { 
                disk.attached?
              }
              
              sleep 0.5
              
              print "Creating ext3 filesystem for #{disk.device}... "
              rbox.mkfs(:t, "ext3", :F, disk.device)
              rbox.mkdir(:p, disk.path)
              puts "done"
              
              print "Mounting at #{disk.path}... "
              
              rbox.mount(:t, 'ext3', disk.device, disk.path)
              disk.mounted = true
              disk.save
              puts "done"
              
            end
          end
          
        end
        
        puts $/, "Filesystem on #{machine.name}:"
        puts rbox.df(:h)
      end
      
    end

  end

end; end