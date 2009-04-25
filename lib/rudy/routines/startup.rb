

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base
    
    # * +routine+ is a single routine configuration hash. If not
    # supplied, the value of fetch_routine_config(:startup) is used.
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(routine=nil, &each_mach)
      rmach = Rudy::Machines.new
      # There's no keypair check here because Rudy::Machines will attempt 
      # to create one.
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      #raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
      
      routine = fetch_routine_config(:startup) unless routine
      
      rbox_local = Rye::Box.new('localhost')
      sconf = fetch_script_config
      
      if Rudy::Routines::ScriptHelper.before_local?(routine)
        # Runs "before_local" scripts of routines config. 
        # NOTE: Does not run "before" scripts b/c there are no remote machines
        puts task_separator("BEFORE SCRIPTS (local)")
        Rudy::Routines::ScriptHelper.before_local(routine, sconf, rbox_local)
      end
      
      #rmach.create do |machine|
      rmach.list do |machine|
        puts machine.liner_note
        print "Waiting for instance..."
        isup = Rudy::Utils.waiter(3, 120, STDOUT, "it's up!", 2) {
          inst = machine.get_instance
          inst && inst.running?
        } 
        machine.update # Add instance info to machine and save it
        print "Waiting for SSH daemon..."
        isup = Rudy::Utils.waiter(2, 60, STDOUT, "it's up!", 3) {
          Rudy::Utils.service_available?(machine.dns_public, 22)
        }
        
        opts = { :keys =>  root_keypairpath, :user => 'root', :debug => nil }
        rbox = Rye::Box.new(machine.dns_public, opts)
        
        if Rudy::Routines::DiskHelper.disks?(routine)
          puts task_separator("DISK ROUTINES")
          # Runs "disk" portion of routines config
          Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
        end
        
        # Use this for Release
        each_mach.call(machine, rbox) if each_mach
        
        if Rudy::Routines::ScriptHelper.after?(routine)
          puts task_separator("AFTER SCRIPTS")
          # Runs "after" scripts of routines config
          Rudy::Routines::ScriptHelper.after(routine, sconf, machine, rbox)
        end
        
        puts task_separator("INFO")
        puts "Filesystem on #{machine.name}:"
        puts "  " << rbox.df(:h).join("#{$/}  ")
      end
      
      if Rudy::Routines::ScriptHelper.after_local?(routine)
        puts task_separator("AFTER SCRIPTS (local)")
        # Runs "after_local" scripts of routines config
        Rudy::Routines::ScriptHelper.after_local(routine, sconf, rbox_local)
      end
      
    end

  end

end; end