

module Rudy; module Routines;

  class Shutdown < Rudy::Routines::Base
    
    def execute
      raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      rmach = Rudy::Machines.new
      routine = fetch_routine_config(:shutdown)
      rbox_local = Rye::Box.new('localhost')
      sconf = fetch_script_config

      # Runs "before_local" scripts of routines config. 
      puts task_separator("BEFORE SCRIPTS (local)")
      Rudy::Routines::ScriptHelper.before_local(routine, sconf, rbox_local)
      
      rmach.destroy do |machine|
      #rmach.list do |machine|
        
        print "Waiting for instance..."
        isup = Rudy::Utils.waiter(3, 120, STDOUT, "it's up!", 0) {
          inst = machine.get_instance
          inst && inst.running?
        } 
        machine.update # Add instance info to machine and save it
        print "Waiting for SSH daemon..."
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "it's up!", 0) {
          Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        # Runs "before" scripts of routines config. 
        puts task_separator("BEFORE SCRIPTS")
        Rudy::Routines::ScriptHelper.before(routine, sconf, machine, rbox)
                
        # Runs "disk" portion of routines config
        puts task_separator("DISK ROUTINES")
        Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
        
        puts machine_separator(machine.liner_note)
      end
      
        
      # Runs "after_local" scripts
      # NOTE: There "after" (remote) scripts are not run b/c the machines
      # are no longer running. 
      puts task_separator("AFTER SCRIPTS (local)")
      Rudy::Routines::ScriptHelper.after_local(routine, sconf, rbox_local)
      
    end

  end

end; end