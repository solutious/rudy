

module Rudy; module Routines;
  class Reboot < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :reboot, self
    
    @@allowed_actions = [:before, :disks, :adduser, :authorize,
                         :before_local, :before_remote, 
                         :local, :remote, :after]
                         
    def init(*args)
      @machines = @rmach.list || []
      @rset = create_rye_set @machines
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
      
      return unless run?
      
      if @routine.has_key? :before_local
        helper = Rudy::Routines.get_helper :local
        Rudy::Routines.rescue {
          helper.execute(:local, @routine.delete(:before_local), nil, @lbox, @option, @argv)
        }
      end
      
      if @routine.has_key? :before_remote
        helper = Rudy::Routines.get_helper :remote
        Rudy::Routines.rescue {
          helper.execute(:remote, @routine.delete(:before_remote), @rset, @lbox, @option, @argv)
        }
      end
      
      @rmach.restart do |machine|
        puts machine_separator(machine.name, machine.awsid)
        
        Rudy::Routines.rescue {
          Rudy::Utils.waiter(3, 120, STDOUT, "Waiting for instance...", 0) {
            inst = machine.get_instance
            inst && inst.running?
          }
        }
        
        sleep 1
        
        # Add instance info to machine and save it. This is really important
        # for the initial startup so the metadata is updated right away. But
        # it's also important to call here because if a routine was executed
        # and an unexpected exception occurs before this update is executed
        # the machine metadata won't contain the DNS information. Calling it
        # here ensure that the metadata is always up-to-date.
        Rudy::Routines.rescue { machine.update }
        
        
        # Windows machine do not have an SSH daemon
        next if (machine.os || '').to_s == 'win32'
        
        Rudy::Routines.rescue {
          Rudy::Utils.waiter(2, 30, STDOUT, "Waiting for SSH daemon...", 0) {
            Rudy::Utils.service_available?(machine.dns_public, 22)
          }
        }
      end
      
      Rudy::Routines.rescue {
        @machines = @rmach.list  
        @rset = create_rye_set @machines
      }
      
      Rudy::Routines::HostnameHelper.set_hostname @rset
      
      # This is the meat of the sandwich
      Rudy::Routines.runner @routine, @rset, @lbox, @option, @argv
      
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


