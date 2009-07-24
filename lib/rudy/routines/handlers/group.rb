
module Rudy; module Routines; module Handlers;
  module Group
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions(name=nil)
      
    end
    
    def create(name=nil)
      name ||= current_group_name
      return if exists? name
      li "Creating group: #{name}"
      Rudy::AWS::EC2::Groups.create name
    end
    
    def exists?(name=nil)
      name ||= current_group_name
      Rudy::AWS::EC2::Groups.exists? name
    end
    
    
  end
end; end; end