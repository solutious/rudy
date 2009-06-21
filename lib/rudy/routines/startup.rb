

module Rudy; module Routines;
  class Startup < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :startup, self
    
    @@allowed_actions = [:before, :before_local, :disks, :adduser, 
                         :authorize, :local, :remote, :after]
    
    def init(*args)
      @routine ||= {}
    end
    
    # Startup routines run in the following order:
    # * before dependencies
    # * before_local (if present)
    # * Startup instances
    # * all other actions
    # * after dependencies
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" if @routine.empty?
      
      return unless run?
      
      Rudy::Routines::DependsHelper.execute_all @before
      
      if @routine.has_key? :before_local
        helper = Rudy::Routines.get_helper :local
        Rudy::Routines.rescue {
          helper.execute(:local, @routine.delete(:before_local), nil, @lbox, @option, @argv)
        }
      end
      
      
      @rmach.create do |machine|
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
      
      # This is the meat of the sandwich
      Rudy::Routines.runner(@routine, @rset, @lbox, @option, @argv)
      
      Rudy::Routines::DependsHelper.execute_all @after
      
      @machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      raise NoMachinesConfig unless @@config.machines
      # There's no keypair check here because Rudy::Machines will create one 
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      # We don't check @@global.offline b/c we can't create EC2 instances
      # without an internet connection. Use passthrough for routine tests.
      #raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
    end
    
  end

end; end
