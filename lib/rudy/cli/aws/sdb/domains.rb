

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Domains < Rudy::CLI::Base
    
    
    def domains
      puts "Domains".bright
      
      sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey)
      
      puts sdb.list_domains

    end
    
  end
  
end; end
end; end