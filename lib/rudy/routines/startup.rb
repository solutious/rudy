

module Rudy; module Routines;
  class Startup < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(:startup)
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(&each_mach)
      routine_separator(:startup)
      unless @routine
        STDERR.puts "[this is a generic startup routine]"
        @routine = {}
      end
      machines = []
      generic_machine_runner(:create) do |machine,rbox|
        puts $/, "Starting up...", $/
        machines << machine
      end
      machines
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