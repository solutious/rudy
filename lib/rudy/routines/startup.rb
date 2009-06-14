

module Rudy; module Routines;
  class Startup < Rudy::Routines::Base
    
    Rudy::Routines.add_handler :startup, self
    
    def init(*args)
      #
    end
    
    def execute
      ld "Executing routine: #{@name}"
      li "[this is a generic routine]" unless @routine
      
      return unless run?
      
      if @routine.has_key? :before_local
        helper = Rudy::Routines.get_helper :local
        enjoy_every_sandwich {
          helper.execute(:local, definition, nil, @lbox, @option, @argv)
        }
      end
      
      @rmach.create do |machine|
        puts machine_separator(machine.name, machine.awsid)
        
        enjoy_every_sandwich {
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
        enjoy_every_sandwich {
          machine.update
        }
        
        # Windows machine do not have an SSH daemon
        next if (machine.os || '').to_s == 'win32'
        
        enjoy_every_sandwich {
          Rudy::Utils.waiter(2, 30, STDOUT, "Waiting for SSH daemon...", 0) {
            Rudy::Utils.service_available?(machine.dns_public, 22)
          }
        }
      end
      
      enjoy_every_sandwich {
        @machines = @rmach.list  
        @rset = create_rye_set @machines
      }
      
      generic_routine_wrapper do |action,definition|
        next if ![:disks, :adduser, :authorize, :after_local, :after].member?(action)
        helper = Rudy::Routines.get_helper action
        enjoy_every_sandwich {
          helper.execute(action, definition, @rset, @lbox, @option, @argv)
        }
      end
      
      @machines
    end

    # Called by generic_machine_runner
    def raise_early_exceptions
      rmach = Rudy::Machines.new
      # There's no keypair check here because Rudy::Machines will create one 
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      # We don't check @@global.offline b/c we can't create EC2 instances
      # without an internet connection. Use passthrough for routine tests.
      raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
    end
    
  end

end; end
