

module Rudy; module Routines;
  class Restart < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(:restart)
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(&each_mach)
      routine_separator(:restart)
      unless @routine
        STDERR.puts "[this is a generic restart routine]"
        @routine = {}
      end
      machines = []
      generic_machine_runner(:list) do |machine,rbox|
        puts $/, "Restarting...", $/
        rbox.disconnect
        machine.restart
        sleep 4
        msg = preliminary_separator("Checking if instance is running...")
        Rudy::Utils.waiter(3, 120, STDOUT, msg, 0) {
          machine.running?
        } 
      
        # Add instance info to machine and save it. This is really important
        # for the initial startup so the metadata is updated right away. But
        # it's also important to call here because if a routine was executed
        # and an unexpected exception occurrs before this update is executed
        # the machine metadata won't contain the DNS information. Calling it
        # here ensure that the metadata is always up-to-date. 
        machine.update 
        
        sleep 4
        
        msg = preliminary_separator("Waiting for SSH daemon...")
        Rudy::Utils.waiter(3, 120, STDOUT, msg, 0) {
          Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        # NOTE: THIS IS INCOMPLETE
        
        sleep 1  # Avoid IOError: closed stream on SSH
        rbox.connect
        
        if Rudy::Routines::DiskHelper.disks?(@routine)         # disk
          puts task_separator("DISKS")
          if rbox.ostype == "sunos"
            puts "Sorry, Solaris is not supported yet!"
          else
            Rudy::Routines::DiskHelper.execute(@routine, machine, rbox)
          end    
        end
        
        machines << machine
      end
      machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      # There's no keypair check here because Rudy::Machines will attempt 
      # to create one.
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
    end
    
  end

end; end