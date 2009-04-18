

module Rudy; module Routines;

  class Shutdown < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      rdisk = Rudy::Disks.new
      routine = fetch_routine_config(:shutdown)

      #rmach.destroy do |machine|
      rmach.list do |machine|
        puts "Destroying #{machine.name}"
        
        isup = Rudy::Utils.waiter(2, 60, STDOUT, nil, nil) { 
          machine.update
          machine.dns_public? && Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
          
      end
    end

  end

end; end