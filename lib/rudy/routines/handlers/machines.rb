
module Rudy; module Routines; module Handlers;
  module Disks
    include Rudy::Routines::Handlers::Base
    extend self
    
    Rudy::Routines.add_handler :machines, self
    
    
  end
end; end; end