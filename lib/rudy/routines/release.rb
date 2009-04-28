

module Rudy; module Routines;
  class Release < Rudy::Routines::Base
    
    def init
      @routine = fetch_routine_config(:release)
    end
    
    def execute
      vlist = []

      # Some early version control system failing
      if Rudy::Routines::VCSHelper.vcs?(@routine)
        vlist = Rudy::Routines::VCSHelper.create_vcs_objects(@routine)
        puts task_separator("CREATING RELEASE TAG#{'S' if vlist.size > 1}")
        vlist.each do |vcs|
          vcs.create_release(Rudy.sysinfo.user)
          puts vcs.liner_note
        end
      end
      
      
      generic_machine_runner(:list) do |machine,rbox|
        vlist.each do |vcs|
          puts task_separator("CREATING REMOTE #{vcs.engine.to_s.upcase} CHECKOUT")
          vcs.create_remote_checkout(rbox)
        end
      end
      
      puts "Done"
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