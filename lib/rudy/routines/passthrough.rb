
module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    Rudy::Routines.add_routine :startup, Rudy::Routines::Startup
    Rudy::Routines.add_routine :shutdown, Rudy::Routines::Shutdown
    Rudy::Routines.add_routine :reboot, Rudy::Routines::Reboot
    
    def init(*args)
      Rudy::Routines.rescue {
        @machines = Rudy::Machines.list || []
        @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
      }
    end
    
    def execute
      Rudy::Routines::Handlers::Depends.execute_all @before, @argv
      li " Executing routine: #{@name} ".att(:reverse), ""
      # Re-retreive the machine set to reflect dependency changes
      Rudy::Routines.rescue {
        @machines = Rudy::Machines.list || []
        @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
      }
      
      return @machines unless run?
      Rudy::Routines.runner(@routine, @@rset, @@lbox, @argv)
      Rudy::Routines::Handlers::Depends.execute_all @after, @argv
      @machines
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @name
      raise NoRoutine, @name unless @routine
      ##raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      # Call raise_early_exceptions for each handler used in the routine
      @routine.each_pair do |action,definition|
        raise NoHandler, action unless Rudy::Routines.has_handler?(action)
        handler = Rudy::Routines.get_handler action
        handler.raise_early_exceptions(action, definition, @@rset, @@lbox, @argv)
      end
    end
    
  end

end; end