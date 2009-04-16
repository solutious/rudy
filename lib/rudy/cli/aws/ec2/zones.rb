

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Zones < Rudy::CLI::CommandBase
    
    
    def zones
      rzone = Rudy::AWS::EC2::Zones.new(@@global.accesskey, @@global.secretkey, @@global.region)
      rzone.list_as_hash(@argv.name).each_value do |zon|
        puts zon.dump(@@global.format)
      end
      puts "No zones" unless rzone.any?
    end
    
    
  end


end; end
end; end
