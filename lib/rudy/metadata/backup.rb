

module Rudy
  class Backup < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    
  end
end