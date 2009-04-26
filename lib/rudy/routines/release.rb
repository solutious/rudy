
module Rudy; module Routines;
  class Release < Rudy::Routines::Base

    def execute
      routine = fetch_routine_config(:release)
      scm = find_scm(routine)

      #puts task_separator("CREATING RELEASE TAG")
      #rel = scm.create_release
      #puts rel
      
      generic_machine_runner(:list, routine) do |machine,rbox|
        puts task_separator("CREATING REMOTE CHECKOUT")
        #scm.create_remote_checkout(rbox)
      end
      
      puts "Done"
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
    end
    
  private
    def find_scm(routine)
      return nil unless routine
      # Look for the source control engine, checking all known scm values.
      # The available one will be a key of the routine hash
      scm_name, params = nil, nil
      SUPPORTED_SCM_NAMES.each do |v|
        next unless routine.has_key?(v)
        scm_name, params = v, routine[v]
        break
      end
      if params
        klass = eval "Rudy::SCM::#{scm_name.to_s.upcase}"
        scm = klass.new(params)
      end
      scm
    end
    
  end
end;end