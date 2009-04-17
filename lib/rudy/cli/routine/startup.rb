

module Rudy; module CLI; module Routine;

  class Startup < Rudy::CLI::CommandBase
  
  
    def startup_valid?
      true
    end
    
    def startup
      
      rr = Rudy::Routine::Startup.new
      rr.execute
      
      
      rmach = Rudy::Machines.new
      rmach.list do |machine|
        puts machine.to_s
      end
      
    end
    

    
  end

end; end; end