

module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    def init(*args)
      @routine_name = args.first
      @routine = fetch_routine_config(@routine_name)
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(&each_mach)
      routine_separator(@routine_name)
      machines = []
      generic_machine_runner(:list) do |machine|
        puts $/, "[just passing through]"
        machines << machine
      end
      
      puts $/, "The following machines were processed:"
      machines.each do |machine|
        puts machine.to_s
      end
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @routine_name
      raise NoRoutine, @routine_name unless @routine
    end
    
  end

end; end