

module Rudy; module CLI; module Routine;

  class Startup < Rudy::CLI::CommandBase
  
  
    def startup_valid?
      true
    end
    
    def startup
      
      rr = Rudy::Routine::Startup.new
      rmach = Rudy::Machines.new
      rr.execute
      rmach.list.each do |machine|
        puts machines.to_s
      end
      
    end
    

    
  end

end; end; end