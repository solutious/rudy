

module Rudy; module Routines;
  class Reboot < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :reboot, self
    
    def init(*args)
      @machines = @rmach.list || []
      @rset = create_rye_set @machines
    end
    
    def execute
      
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


