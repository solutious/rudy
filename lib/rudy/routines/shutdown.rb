

module Rudy; module Routines;
  class Shutdown < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :shutdown, self
    
    @@allowed_actions = [:before, :disks, :adduser, :authorize,
                         :local, :remote, :after_local, :after]
                         
    def init(*args)
      @machines = @rmach.list || []
      @@rset = create_rye_set @machines unless defined?(@@rset)
      @routine ||= {}
    end
    
    # Startup routines run in the following order:
    # * before dependencies
    # * all other actions (except after_local)
    # * Shutdown instances
    # * after_local (if present)
    # * after dependencies
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" if @routine.empty?
      
      # We need to remove after_local so the runner doesn't see it
      after_local = @routine.delete(:after_local)
      
      if run?
        Rudy::Routines::DependsHelper.execute_all @before
      
        # This is the meat of the sandwich
        Rudy::Routines.runner(@routine, @@rset, @@lbox, @argv)
      
        @machines.each do |machine|
          Rudy::Routines.rescue { machine.destroy }
        end
      
        if after_local
          helper = Rudy::Routines.get_helper :local
          Rudy::Routines.rescue {
            helper.execute(:local, after_local, nil, @@lbox, @argv)
          }
        end
      
        Rudy::Routines::DependsHelper.execute_all @after
      end
      
      @machines
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise NoMachinesConfig unless @@config.machines
      
      # If this is a test run we don't care if the group is running
      if run?
        raise MachineGroupNotRunning, current_machine_group unless rmach.running?
      end
      
      ## NOTE: This check is disabled for now. If the private key doesn't exist
      ## it prevents shutting down.
      # Check private key after machine group, otherwise we could get an error
      # about there being no key which doesn't make sense if the group isn't running.
      ##raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
    end
    
  end

end; end

