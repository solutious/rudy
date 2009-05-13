

module Rudy; module Routines;
  class Release < Rudy::Routines::Base
    
    def init(*args)
      @routine_name = args.first || :release # :release or :rerelease
      @routine = fetch_routine_config(@routine_name)
    end
    
    def execute()
      routine_separator(@routine_name)

      vlist = []
      
      # Some early version control system failing
      if Rudy::Routines::SCMHelper.scm?(@routine)
        vlist = Rudy::Routines::SCMHelper.create_scm_objects(@routine)
        puts task_separator("CREATING RELEASE TAG#{'S' if vlist.size > 1}")
        vlist.each do |scm|
          scm.create_release(Rudy.sysinfo.user)
          puts scm.liner_note
        end
      end
      
      machines = generic_machine_runner(:list) do |machine,rbox|
        vlist.each do |scm|
          puts task_separator("CREATING REMOTE #{scm.engine.to_s.upcase} CHECKOUT")
          scm.create_remote_checkout(rbox)
        end
      end
      
      machines
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      raise NoRoutine, :release unless @routine
      rmach = Rudy::Machines.new
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
    end
    

    
  end
end;end