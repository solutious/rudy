
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
    
    def authorize(name=nil, addresses=nil, ports=nil)
      name ||= current_group_name
      addresses ||= [Rudy::Utils::external_ip_address]
      if ports.nil?
        ports = current_machine_os.to_s == 'win32' ? [[3389,3389]] : [[22,22]]
      end
      li "Authorizing ports #{ports.inspect} access for: #{addresses.join(', ')}"
      Rudy::AWS::EC2::Groups.authorize(name, addresses, ports) 
    end
    
    def exists?(name=nil)
      name ||= current_group_name
      Rudy::AWS::EC2::Groups.exists? name
    end
    
    def destroy(name=nil)
      name ||= current_group_name
      return unless exists? name
      li "Destroying group: #{name}"
      Rudy::AWS::EC2::Groups.destroy name
    end
    
  end
end; end; end