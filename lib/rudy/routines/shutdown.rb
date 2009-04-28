

module Rudy; module Routines;
  class Shutdown < Rudy::Routines::Base
    
    def init
      @routine = fetch_routine_config(:shutdown)
    end
    
    def execute
      generic_machine_runner(:destroy) do |machine,rbox|
        #puts task_separator("SHUTDOWN")
      end
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise NoRoutine, :shutdown unless @routine
      rmach = Rudy::Machines.new
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
    end
    
  end

end; end