

module Rudy; module Routines;
  class Reboot < Rudy::Routines::Base
    
    Rudy::Routines.add_routine :reboot, self
    
    @@allowed_actions = [:before, :disks, :adduser, :authorize,
                         :before_local, :before_remote, 
                         :local, :remote, :after]
                         
    def init(*args)
      @routine ||= {}
      Rudy::Routines.rescue {
        @machines = Rudy::Machines.list || []
        @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
      }
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
      
      if run?
        Rudy::Routines::Handlers::Depends.execute_all @before, @argv
        
        li " Executing routine: #{@name} ".att(:reverse), ""
        ld "[this is a generic routine]" if @routine.empty?
        
        # Re-retreive the machine set to reflect dependency changes
        Rudy::Routines.rescue {
          @machines = Rudy::Machines.list || []
          @@rset = Rudy::Routines::Handlers::RyeTools.create_set @machines
        }
        
        Rudy::Routines.rescue {
          Rudy::Routines::Handlers::Group.authorize rescue nil
        }
        
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
        if Rudy::Routines::Handlers::Disks.mount? @routine
          fake = Hash[:umount => @routine.disks[:mount]]
          Rudy::Routines::Handlers::Disks.execute :umount, fake, @@rset, @@lbox, @argv
        end
      }
      
      li "Rebooting #{current_group_name}..."
      @machines.each { |m| m.restart } if run?
      
      15.times { print '.'; Kernel.sleep 2 }; li $/  # Wait for 30 seconds
      
      Rudy::Routines.rescue {
        if !Rudy::Routines::Handlers::Host.is_running? @@rset
          a = @@rset.boxes.select { |box| !box.stash.instance_running? }
          raise GroupNotRunning, a
        end
      }
      
      # This is important b/c the machines will not 
      # have DNS info until after they are running. 
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
      # There's no keypair check here because Rudy::Machines will attempt 
      # to create one.
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      # If this is a test run we don't care if the group is running
      if run?
        raise MachineGroupNotRunning, current_machine_group unless Rudy::Machines.running?
      end
      
      if @routine
        bad = @routine.keys - @@allowed_actions
        raise UnsupportedActions.new(@name, bad) unless bad.empty?
      end
      
      if @machines
        down = @@rset.boxes.select { |box| !box.stash.instance_running? }
        raise GroupNotAvailable, down unless down.empty?
      end
      
    end
    
  end

end; end


