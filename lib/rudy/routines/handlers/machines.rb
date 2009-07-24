
module Rudy; module Routines; module Handlers;
  module Machines
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions
    end
    
    
    def create_security_group
      unless Rudy::AWS::EC2::Groups.exists?(current_group_name)
        li "Creating group: #{current_group_name}"
        Rudy::AWS::EC2::Groups.create(current_group_name)
      end
    end
      
    
  end
end; end; end