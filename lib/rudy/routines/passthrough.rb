

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
      generic_machine_runner(:list) do |machine,rbox|
        puts $/ #, "[routine: #{@routine_name}]"
        machines << machine
      end
      machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @routine_name
      raise NoRoutine, @routine_name unless @routine
      rmach = Rudy::Machines.new
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      if !@@global.offline && !rmach.running?
        raise MachineGroupNotRunning, current_machine_group
      end
    end
    
  end

end; end