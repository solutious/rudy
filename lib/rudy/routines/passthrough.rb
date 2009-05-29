

module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(@cmdname)
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(&each_mach)
      routine_separator(@cmdname)
      machines = []
      generic_machine_runner(:list) do |machine,rbox|
        puts $/ #, "[routine: #{@cmdname}]"
        machines << machine
      end
      machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @cmdname
      raise NoRoutine, @cmdname unless @routine
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      ##rmach = Rudy::Machines.new
      ##if !@@global.offline && !rmach.running?
      ##  raise MachineGroupNotRunning, current_machine_group
      ##end
    end
    
  end

end; end