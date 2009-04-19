

module Rudy; module CLI;
  class Routines < Rudy::CLI::CommandBase
  
    def startup
      rr = Rudy::Routines::Startup.new
      rr.execute
      
      puts $/, "The following machines are now available:"
      rmach = Rudy::Machines.new
      rmach.list do |machine|
        puts machine.to_s
      end
      
      if @@global.environment == @@config.defaults.environment && 
         @@global.role == @@config.defaults.role
         puts
         puts "Try: #{$0} -u root ssh"
      end
      
    end
    
    def release
      rr = Rudy::Routines::Release.new
      rmach = Rudy::Machines.new
      startup unless rmach.running?
      rr.execute
    end
    
    def shutdown
      rr = Rudy::Routines::Shutdown.new
      routine = fetch_routine_config(:shutdown)

      puts "All machines in #{current_machine_group} will be shutdown and"
      if routine && routine.disks
        if routine.disks.destroy
          puts "the following filesystems will be destroyed:".color(:red)
          puts routine.disks.destroy.keys.join($/).bright
        end
      end
      
      execute_check :medium
      
      rr.execute
      
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rinst.list_group(current_machine_group, :any) do |inst|
        puts @@global.verbose > 0 ? inst.inspect : inst.dump(@@global.format)
      end
      puts "No instances running" if !lt || lt.empty?
    end
    

  end
end; end

