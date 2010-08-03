

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
      
      if run?
        Rudy::Routines::Handlers::Depends.execute_all @before, @argv
        
        li " Executing routine: #{@name} ".att(:reverse), ""
        ld "[this is a generic routine]" if @routine.empty?
        
        if @routine.has_key? :before_local
          handler = Rudy::Routines.get_handler :local
          Rudy::Routines.rescue {
            handler.execute(:local, @routine.delete(:before_local), nil, @@lbox, @argv)
          }
        end
        
        Rudy::Routines.rescue {
          unless Rudy::Routines::Handlers::Group.exists? 
            Rudy::Routines::Handlers::Group.create
          end
          # Run this every startup incase the ip address has changed. 
          # If there's an exception it's probably b/c the address is
          # already authorized for port 22. 
          Rudy::Routines::Handlers::Group.authorize rescue nil
        }
        
        Rudy::Routines.rescue {
          unless Rudy::Routines::Handlers::Keypair.exists? 
            Rudy::Routines::Handlers::Keypair.create
          end
        }
        
      end
      
      ## li Rudy::Routines.machine_separator(machine.name, machine.awsid)
      
      # If this is a testrun we won't create new instances
      # we'll just grab the list of machines in this group. 
      # NOTE: Expect errors if there are no machines.
      Rudy::Routines.rescue {
        @machines = run? ? Rudy::Machines.create : Rudy::Machines.list
        @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
      }
      
      
      Rudy::Routines.rescue {
        if !Rudy::Routines::Handlers::Host.is_running? @@rset
          a = @@rset.boxes.select { |box| !box.stash.instance_running? }
          raise GroupNotRunning, a
        end
      }
      
      # This is important b/c the machines will not 
      # have DNS info until after they are running. 
      # This will also assign elastic IP addresses. 
      Rudy::Routines.rescue { Rudy::Routines::Handlers::Host.update_dns @@rset }
      
      Rudy::Routines.rescue {
        if !Rudy::Routines::Handlers::Host.is_available? @@rset
          a = @@rset.boxes.select { |box| !box.stash.instance_available? }
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
          Rudy::Routines::Handlers::Depends.execute_all @after, @argv
        }
        
      end
      
      @machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      raise NoMachinesConfig unless @@config.machines
      # There's no keypair check here because Rudy::Machines will create one 
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
        
      unless (1..MAX_INSTANCES).member?(current_machine_count)
        raise "Instance count must be more than 0, less than #{MAX_INSTANCES}"
      end
      
      # If this is a testrun, we don't create instances anyway so
      # it doesn't matter if there are already instances running.
      if run? && !@@global.force
        if @@global.position.nil?
          raise MachineGroupAlreadyRunning, current_machine_group if Rudy::Machines.running?
          #raise MachineGroupMetadataExists, current_machine_group if Rudy::Machines.exists?
        else
          if Rudy::Machines.running? @@global.position
            m = Rudy::Machine.new @@global.position
            raise MachineAlreadyRunning, m.name 
          end
        end
      end
      
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
    end
    
  end

end; end
