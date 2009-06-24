

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'metadata', '*.rb')