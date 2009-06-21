
module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    def init(*args)
      @machines = @rmach.list || []
      @rset = create_rye_set @machines
    end
    
    def execute
      ld "Executing routine: #{@name}"

      return @machines unless run?
      
      Rudy::Routines::DependsHelper.execute_all @before
      
      # This is the meat of the sandwich
      Rudy::Routines.runner(@routine, @rset, @lbox, @option, @argv)
      
      Rudy::Routines::DependsHelper.execute_all @after

      @machines
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @name
      raise NoRoutine, @name unless @routine
      ##raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      # Call raise_early_exceptions for each helper used in the routine
      @routine.each_pair do |action,definition|
        raise NoHelper, action unless Rudy::Routines.has_helper?(action)
        helper = Rudy::Routines.get_helper action
        helper.raise_early_exceptions(action, definition, @rset, @lbox, @option, @argv)
      end
    end
    
  end

end; end