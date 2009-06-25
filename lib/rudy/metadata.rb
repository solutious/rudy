

module Rudy
  module Metadata
    include Rudy::Huxtable
    extend self
    
    def domain(name=nil)
      return @@domain if name.nil?
      @@domain = name
    end
    
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'metadata', '*.rb')