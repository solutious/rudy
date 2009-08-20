

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Zones < Rudy::CLI::CommandBase
    
    
    def zones
      zlist = Rudy::AWS::EC2::Zones.list(@argv.name)
      print_stobjects zlist
    end
    
    
  end


end; end
end; end
