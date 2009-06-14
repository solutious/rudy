

module Rudy; module Routines;
  class Shutdown < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :shutdown, self
    
    def init(*args)
      @machines = @rmach.list || []
      @rset = create_rye_set @machines
    end
    
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" unless @routine
      
      return unless run?
      
      generic_routine_wrapper do |action,definition|
        next if ![:disks, :adduser, :authorize, :before_local, :before].member?(action)
        helper = Rudy::Routines.get_helper action
        enjoy_every_sandwich {
          helper.execute(action, definition, @rset, @lbox, @option, @argv)
        }
      end
      
      @machines.each do |machine|
        enjoy_every_sandwich { machine.destroy }
      end
      
      if @routine.has_key? :after_local
        helper = Rudy::Routines.get_helper :local
        enjoy_every_sandwich {
          helper.execute(:local, definition, nil, @lbox, @option, @argv)
        }
      end
      
      @machines
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise MachineGroupNotRunning, current_machine_group unless rmach.running?
      ## NOTE: This check is disabled for now. If the private key doesn't exist
      ## it prevents shutting down.
      # Check private key after machine group, otherwise we could get an error
      # about there being no key which doesn't make sense if the group isn't running.
      ##raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
    end
    
  end

end; end

