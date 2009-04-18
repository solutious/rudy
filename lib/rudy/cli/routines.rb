

module Rudy; module CLI;
  class Routines < Rudy::CLI::CommandBase
  
    def startup
      rr = Rudy::Routines::Startup.new
      rr.execute
      
      rmach = Rudy::Machines.new
      rmach.list do |machine|
        puts machine.to_s
      end
      
    end
  
  
    def shutdown
      rr = Rudy::Routines::Shutdown.new
      routine = fetch_routine_config(:shutdown)

      puts "All machines in #{current_machine_group} will be shutdown".color(:red)
      if routine.disks
        if routine.disks.destroy
          puts "The following filesystems will be destroyed:".color(:red)
          puts routine.disks.destroy.keys
        end
      end
      
      execute_check :medium
      
      rr.execute
      
    end
    

  end
end; end

