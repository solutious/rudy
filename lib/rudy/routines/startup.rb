

module Rudy; module Routines;

  class Startup < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
            
      routine = fetch_routine_config(:startup)
      
      rmach.create do |m|
        
      end
      
    end

  end

end; end