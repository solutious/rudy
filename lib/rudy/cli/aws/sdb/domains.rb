

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Domains < Rudy::CLI::Base
    
    
    def domains
      puts "Domains".bright, $/
      
      sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey)
      
      #puts sdb.create_domain('crazy')
      p sdb.list_domains
      #puts sdb.destroy_domain('crazy')
    end
    
  end
  
end; end
end; end