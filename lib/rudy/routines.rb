

module Rudy
  module Routines
    class Base
      include Rudy::Huxtable
    
      def initialize
        a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
        @sdb = Rudy::AWS::SDB.new(a, s, r)
        @rinst = Rudy::AWS::EC2::Instances.new(a, s, r)
        @rgrp = Rudy::AWS::EC2::Groups.new(a, s, r)
        @rkey = Rudy::AWS::EC2::KeyPairs.new(a, s, r)
        @rvol = Rudy::AWS::EC2::Volumes.new(a, s, r)
        @rsnap = Rudy::AWS::EC2::Snapshots.new(a, s, r)
        init
      end
      
      def init
      end
      

      def execute
        raise "Override execute method"
      end
      
      def raise_early_exceptions
        raise "Must override raise_early_exceptions"
      end
      
      # * +machine_action+ a method on Rudy::Machines, likely one of: create, destroy, list
      # * +routine+ is a single routine configuration hash. REQUIRED.
      # * +routine_action+ is an optional block which represents the action
      # for a specific routine. For example, a startup routine will start
      # an EC2 instance. Arguments: instances of Rudy::Machine and Rye::Box.
      def generic_machine_runner(machine_action, routine, &routine_action)
        raise_early_exceptions
        rmach = Rudy::Machines.new
        raise "No routine supplied" unless routine
        raise "No machine action supplied" unless machine_action
        unless rmach.respond_to?(machine_action)
          raise "Unknown machine action #{machine_action}" 
        end
        #raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?

        rbox_local = Rye::Box.new('localhost')
        sconf = fetch_script_config

        if Rudy::Routines::ScriptHelper.before_local?(routine)
          # Runs "before_local" scripts of routines config. 
          # NOTE: Does not run "before" scripts b/c there are no remote machines
          puts task_separator("BEFORE SCRIPTS (local)")
          Rudy::Routines::ScriptHelper.before_local(routine, sconf, rbox_local)
        end

        rmach.send(machine_action) do |machine|
          puts machine_separator(machine.name, machine.awsid)

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

          if Rudy::Routines::ScriptHelper.before?(routine)
            # Runs "before" scripts of routines config. 
            puts task_separator("BEFORE SCRIPTS")
            Rudy::Routines::ScriptHelper.before(routine, sconf, machine, rbox)
          end
          
          if Rudy::Routines::DiskHelper.disks?(routine)
            puts task_separator("DISK ROUTINES")
            # Runs "disk" portion of routines config
            Rudy::Routines::DiskHelper.execute(routine, machine, rbox)
          end

          # Startup machines, shutdown machines, release application, etc...
          routine_action.call(machine, rbox) if routine_action

          if Rudy::Routines::ScriptHelper.after?(routine)
            puts task_separator("AFTER SCRIPTS")
            # Runs "after" scripts of routines config
            Rudy::Routines::ScriptHelper.after(routine, sconf, machine, rbox)
          end

          if Rudy::Routines::DiskHelper.disks?(routine)
            # TODO: Print only the requested disks
            puts task_separator("INFO")
            puts "Filesystem on #{machine.name}:"
            puts "  " << rbox.df(:h).join("#{$/}  ")
          end
        end

        if Rudy::Routines::ScriptHelper.after_local?(routine)
          puts task_separator("AFTER SCRIPTS (local)")
          # Runs "after_local" scripts of routines config
          Rudy::Routines::ScriptHelper.after_local(routine, sconf, rbox_local)
        end

      end
      
      def task_separator(title)
        dashes = 52 - title.size # 
        dashes = 0 if dashes < 1
        ("%s===  %s  %s" % [$/, title, '='*dashes])
      end
      
      def machine_separator(name, awsid)
        dashes = 60 - name.size # 
        dashes = 0 if dashes < 1
        puts $/, '='*60
        puts 'MACHINE: %-40s (%s)' % [name.bright, awsid]
        puts '='*60, $/
      end

    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', 'helpers', '*.rb')
Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', '*.rb')


