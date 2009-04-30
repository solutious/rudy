

module Rudy; module CLI;
  class Routines < Rudy::CLI::CommandBase
    
    def startup_valid?
      @rr = Rudy::Routines::Startup.new
      @rr.raise_early_exceptions
      true
    end
    def startup

      @rr.execute
      
      puts $/, "The following machines are now available:"
      rmach = Rudy::Machines.new
      rmach.list do |machine|
        puts machine.to_s
      end
      
      if @@global.environment == @@config.defaults.environment && 
         @@global.role == @@config.defaults.role
         #puts
         #puts "Login with: rudy -u root ssh"
      end
      
    end
    
    def release_valid?
      @rr = Rudy::Routines::Release.new
      @rr.raise_early_exceptions
      true
    end
    def release
      @rr.execute 
    end
    
    def passthrough_valid?
      @rr = Rudy::Routines::Passthrough.new(@alias)
      @rr.raise_early_exceptions
      true
    end
    
    # All unknown commands are sent here (using Drydock's trawler). 
    # By default, the generic passthrough routine is executed which
    # does nothing other than execute the routine config block that
    # matches +@alias+ (the name used on the command-line). Calling
    #
    #     $ rudy unknown
    #
    # would end up here because it's an unknown command. Passthrough
    # then looks for a routine config in the current environment and
    # role called "unknown". If found, it's executed otherwise it'll
    # raise an exception.
    #
    def passthrough
      machines = @rr.execute
      
      unless machines.empty?
        puts $/, "The following machines were processed:"
        machines.each do |machine|
          puts machine.to_s
        end
      end
      
    end
    
    def shutdown_valid?
      @rr = Rudy::Routines::Shutdown.new
      @rr.raise_early_exceptions
      true
    end
    def shutdown
      routine = fetch_routine_config(:shutdown)
      
      puts "All machines in #{current_machine_group} will be shutdown"
      if routine && routine.disks
        if routine.disks.destroy
          puts "The following filesystems will be destroyed:".color(:red)
          puts routine.disks.destroy.keys.join($/).bright
        end
      end
      
      execute_check :medium
      
      @rr.execute
      
      puts $/, "The following instances have been destroyed:"
      
      # We select instances here b/c the Machine metadata should be destroyed. 
      # This "low-level" view will reveal any machine which may have not 
      # been shut down (which would be erroneous).
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rinst.list_group(current_group_name, :any)
      if !lt || lt.empty?
        puts "No instances running"
      else
        lt.each do |inst|
          puts @@global.verbose > 0 ? inst.inspect : inst.dump(@@global.format)
        end
      end
      
    end
    

  end
end; end

