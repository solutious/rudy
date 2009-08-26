
module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    def init(*args)
      @machines = Rudy::Machines.list || []
      @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
    end
    
    def execute
      li "Executing routine: #{@name}"
      return @machines unless run?
      Rudy::Routines::Handlers::Depends.execute_all @before
      Rudy::Routines.runner(@routine, @@rset, @@lbox, @argv)
      Rudy::Routines::Handlers::Depends.execute_all @after
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