

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Domains < Rudy::CLI::Base
    
    
    def domains
      puts "Domains".bright, $/
      
      rdom = Rudy::Domains.new
      puts rdom.list
    end
    
  end
  
end; end
end; end