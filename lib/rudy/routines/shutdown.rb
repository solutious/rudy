

module Rudy; module Routines;
  class Shutdown < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config(:shutdown)
    end
    
    def execute
      routine_separator(:shutdown)
      unless @routine
        STDERR.puts "[this is a generic shutdown routine]"
        @routine = {}
      end
      generic_machine_runner(:destroy) do |machine,rbox|
        #puts task_separator("SHUTDOWN")
      end
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
    end
    
  end

end; end