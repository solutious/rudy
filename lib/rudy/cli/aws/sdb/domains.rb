

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Domains < Rudy::CLI::CommandBase
    
    
    def domains

      sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      
      puts sdb.list_domains

    end
    
  end
  
end; end
end; end