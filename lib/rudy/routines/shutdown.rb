

module Rudy; module Routines;

  class Shutdown < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      routine = fetch_routine_config(:shutdown)
      rbox_local = Rye::Box.new('localhost')
      sconf = fetch_script_config

      #rmach.destroy do |machine|
      rmach.list do |machine|
        
        isup = Rudy::Utils.waiter(2, 60, STDOUT, nil, nil) { 
          machine.update
          machine.dns_public? && Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        # Runs "before_local" and "before" scripts of routines config. 
        puts task_separator("BEFORE SCRIPTS")
        Rudy::Routines::ScriptHelper.before_local(routine, sconf, rbox_local)
        Rudy::Routines::ScriptHelper.before(routine, sconf, machine, rbox)
                
        # Runs "disk" portion of routines config
        puts task_separator("DISK ROUTINES")
        Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
        
      end
      
        
      # Runs "after_local" scripts
      # NOTE: There "after" (remote) scripts are not run b/c the machines
      # are no longer running. 
      puts task_separator("AFTER SCRIPTS")
      Rudy::Routines::ScriptHelper.after_local(routine, sconf, rbox_local)
      
    end

  end

end; end