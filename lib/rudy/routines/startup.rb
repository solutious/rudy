

module Rudy; module Routines;
  class Startup < Rudy::Routines::Base
    
    Rudy::Routines.add_routine :startup, self
    
    @@allowed_actions = [:before, :before_local, :disks, :adduser, 
                         :authorize, :local, :remote, :after]
    
    def init(*args)
      @routine ||= {}
    end
    
    # Startup routines run in the following order:
    # * before dependencies
    # * before_local (if present)
    # * Startup instances
    # * Set hostname
    # * all other actions
    # * after dependencies
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" if @routine.empty?
      
      
      if run?
        Rudy::Routines::Handlers::Depends.execute_all @before
      
        if @routine.has_key? :before_local
          handler = Rudy::Routines.get_handler :local
          Rudy::Routines.rescue {
            handler.execute(:local, @routine.delete(:before_local), nil, @@lbox, @argv)
          }
        end
        
        
        unless (1..MAX_INSTANCES).member?(current_machine_count)
          raise "Instance count must be more than 0, less than #{MAX_INSTANCES}"
        end

        unless @rgrp.exists?(current_group_name)
          puts "Creating group: #{current_group_name}"
          @rgrp.create(current_group_name)
        end
        
        unless @rkey.exists?(root_keypairname)
          kp_file = File.join(Rudy::CONFIG_DIR, root_keypairname)
          raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
          puts "Creating keypair: #{root_keypairname}"
          kp = @rkey.create(root_keypairname)
          puts "Saving #{kp_file}"
          Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
        else
          kp_file = root_keypairpath
          # This means no keypair file can be found
          raise PrivateKeyNotFound, root_keypairname if kp_file.nil?
          # This means we found a keypair in the config but we cannot find the private key file.
          raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
        end
        
      end
      
      ## puts Rudy::Routines.machine_separator(machine.name, machine.awsid)
      
      # If this is a testrun we won't create new instances
      # we'll just grab the list of machines in this group. 
      # NOTE: Expect errors if there are no machines.
      @machines = run? ? @rmach.create : @rmach.list
      @@rset = create_rye_set @machines unless defined?(@@rset)
      
      Rudy::Routines.rescue {
        if !Rudy::Routines::Handlers::Host.is_running? @@rset
          a = @@rset.boxes.select { |box| !box.stash.running? }
          raise GroupNotRunning, a
        end
      }
      
      # This is important b/c the machines will not 
      # have DNS info until after they are running. 
      Rudy::Routines.rescue { Rudy::Routines::Handlers::Host.update_dns @@rset }
      
      Rudy::Routines.rescue {
        if !Rudy::Routines::Handlers::Host.is_available? @@rset
          a = @@rset.boxes.select { |box| !box.stash.available? }
          raise GroupNotAvailable, a
        end
      }
      Rudy::Routines.rescue {
        Rudy::Routines::Handlers::Host.set_hostname @@rset      
      }

      if run?
        # This is the meat of the sandwich
        Rudy::Routines.runner @routine, @@rset, @@lbox, @argv
        
        Rudy::Routines.rescue {
          Rudy::Routines::Handlers::Depends.execute_all @after
        }
      end
      
      @machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise NoMachinesConfig unless @@config.machines
      # There's no keypair check here because Rudy::Machines will create one 
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      # If this is a testrun, we don't create instances anyway so
      # it doesn't matter if there are already instances running.
      if run?
        # We don't check @@global.offline b/c we can't create EC2 instances
        # without an internet connection. Use passthrough for routine tests.
        raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
      end
      
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
    end
    
  end

end; end
