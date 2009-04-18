

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base

    def execute
      rmach = Rudy::Machines.new
      routine = fetch_routine_config(:startup)
      rbox_local = Rye::Box.new('localhost')
      sconf = fetch_script_config
      
      # Runs "before_local" scripts of routines config. 
      # NOTE: Does not run "before" scripts b/c there are no remote machines
      puts task_separator("BEFORE SCRIPTS")
      Rudy::Routines::ScriptHelper.before_local(routine, sconf, rbox_local)
      
      #rmach.create do |machine|
      rmach.list do |machine|
      
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "SSH is available", nil) { 
          machine.update
          hostname = machine.dns_public
          machine.dns_public? && Rudy::Utils.service_available?(hostname, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        puts task_separator("DISK ROUTINES")
        # Runs "disk" portion of routines config
        #Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
        
        puts task_separator("AFTER SCRIPTS")
        # Runs "after_local", then "after" scripts of routines config
        Rudy::Routines::ScriptHelper.after_local(routine, sconf, rbox_local)
        Rudy::Routines::ScriptHelper.after(routine, sconf, machine, rbox)
        
        puts task_separator("INFO")
        puts "Filesystem on #{machine.name}:"
        puts "  " << rbox.df(:h).join("#{$/}  ")
      end
      
    end

  end

end; end