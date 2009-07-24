
module Rudy; module Routines; module Handlers;
  module Machines
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions
    end
    
    
  end
end; end; end