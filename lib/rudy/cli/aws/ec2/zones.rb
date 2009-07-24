

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Zones < Rudy::CLI::CommandBase
    
    
    def zones
      Rudy::AWS::EC2::Zones.list_as_hash(@argv.name).each_value do |zon|
        puts zon.dump(@@global.format)
      end
      puts "No zones" unless Rudy::AWS::EC2::Zones.any?
    end
    
    
  end


end; end
end; end
