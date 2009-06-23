

module Rudy; module Routines;
  class Reboot < Rudy::Routines::Base
    
    Rudy::Routines.add_routine :reboot, self
    
    @@allowed_actions = [:before, :disks, :adduser, :authorize,
                         :before_local, :before_remote, 
                         :local, :remote, :after]
                         
    def init(*args)
      @routine ||= {}
    end
    
    # Startup routines run in the following order:
    # * before_local (if present)
    # * before_remote (if present)
    # * Reboot instances
    # * Set hostname
    # * before dependencies
    # * all other actions
    # * after dependencies
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" if @routine.empty?

      
      # If this is a testrun we won't create new instances
      # we'll just grab the list of machines in this group. 
      # NOTE: Expect errors if there are no machines.
      @machines = run? ? @rmach.restart : @rmach.list
      @@rset = create_rye_set @machines unless defined?(@@rset)
      
      if run?
        if @routine.has_key? :before_local
          handler = Rudy::Routines.get_handler :local
          Rudy::Routines.rescue {
            handler.execute(:local, @routine.delete(:before_local), nil, @@lbox, @argv)
          }
        end
      
        if @routine.has_key? :before_remote
          handler = Rudy::Routines.get_handler :remote
          Rudy::Routines.rescue {
            handler.execute(:remote, @routine.delete(:before_remote), @@rset, @@lbox, @argv)
          }
        end
      end
      
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
      rmach = Rudy::Machines.new
      raise NoMachinesConfig unless @@config.machines
      # There's no keypair check here because Rudy::Machines will attempt 
      # to create one.
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      # If this is a test run we don't care if the group is running
      if run?
        raise MachineGroupNotRunning, current_machine_group unless rmach.running?
      end
      
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
    end
    
  end

end; end


