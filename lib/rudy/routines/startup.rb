

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base
    
    # * +routine+ is a single routine configuration hash. If not
    # supplied, the value of fetch_routine_config(:startup) is used.
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(routine=nil, &each_mach)
      routine = fetch_routine_config(:startup) unless routine      
      generic_machine_runner(:create, routine) do |machine,rbox|
        #puts task_separator("STARTUP")
      end
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      # There's no keypair check here because Rudy::Machines will attempt 
      # to create one.
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
    end
    
  end

end; end