

module Rudy; module Routines;
  class Startup < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(:startup)
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    # Returns an Array of Rudy::Machine objects
    def execute(&each_mach)
      routine_separator(:startup)
      unless @routine
        STDERR.puts "[this is a generic startup routine]"
        @routine = {}
      end
      machines = generic_machine_runner(:create) 
      machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      # There's no keypair check here because Rudy::Machines will create one 
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      # We don't check @@global.offline b/c we can't create EC2 instances
      # without an internet connection. Use passthrough for routine tests.
      raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
    end
    
  end

end; end