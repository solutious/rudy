module Rudy
  
  module Backups
    RTYPE = 'back'.freeze
    
    extend self
    extend Rudy::Metadata::ClassMethods 
    extend Rudy::Huxtable
    
  end
  
end