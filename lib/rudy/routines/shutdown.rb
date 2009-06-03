

module Rudy; module Routines;
  class Shutdown < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(:shutdown)
    end
    
    def execute
      routine_separator(:list)
      unless @routine
        STDERR.puts "[this is a generic shutdown routine]"
        @routine = {}
      end

      machines = generic_machine_runner(:list) do |machine|
        machine.destroy
      end
      machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
      # Check private key after machine group, otherwise we could get an error
      # about there being no key which doesn't make sense if the group isn't running.
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
    end
    
  end

end; end