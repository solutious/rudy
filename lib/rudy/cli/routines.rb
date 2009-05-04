

module Rudy; module CLI;
  class Routines < Rudy::CLI::CommandBase
    
    def startup_valid?
      @rr = Rudy::Routines::Startup.new
      @rr.raise_early_exceptions
      true
    end
    def startup
      machines = @rr.execute
      puts $/, "The following machines are now available:"
      machines.each do |machine|
        puts machine.to_s
      end
    end
    
    def restart_valid?
      @rr = Rudy::Routines::Restart.new
      @rr.raise_early_exceptions
      true
    end
    def restart
      #machines = @rr.execute
      #puts $/, "The following machines have been restarted:"
      #machines.each do |machine|
      #  puts machine.to_s
      #end
      #puts "Restart is disabled"
    end
    
    def release_valid?
      @rr = Rudy::Routines::Release.new
      @rr.raise_early_exceptions
      true
    end
    def release
      machines = @rr.execute
      
      unless machines.empty?
        puts $/, "The following machines were processed:"
        machines.each do |machine|
          puts machine.to_s
        end
      end
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
          puts @@global.verbose > 0 ? machine.inspect : machine.dump(@@global.format)
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
      
      puts "All machines in #{current_machine_group} will be shutdown".bright
      if routine && routine.disks
        if routine.disks.destroy
          puts "The following filesystems will be destroyed:".bright
          puts routine.disks.destroy.keys.join($/).bright
        end
      end
      
      execute_check :medium
      
      machines = @rr.execute
      puts $/, "The following instances have been destroyed:"
      machines.each do |machine|
        puts '%s %s ' % [machine.name.bright, machine.awsid]
      end
      
      
    end
    

  end
end; end

