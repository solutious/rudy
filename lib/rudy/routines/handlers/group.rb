
module Rudy; module Routines; module Handlers;
  module Group
    include Rudy::Routines::Handlers::Base
    extend self
    
    Rudy::Routines.add_handler :network, self
    
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def execute(type, routine, rset, lbox, argv=nil)
      routine.each_pair do |action, definition|
        unless respond_to?(action.to_sym)  
          Rudy::Huxtable.le %Q(GroupHandler: unknown action "#{action}")
          next
        end
        Rudy::Huxtable.ld %Q(GroupHandler: "#{action}")
        Rudy::Routines::Handlers::Group.send(action, definition)
      end
    end
    
    def create(name=nil)
      name ||= current_group_name
      return if exists? name
      li "Creating group: #{name}"
      Rudy::AWS::EC2::Groups.create name
    end
    
    def authorize(ports=nil, addresses=nil, name=nil)      
      modify(:authorize, ports, addresses, name)
    end
    
    def revoke(ports=nil, addresses=nil, name=nil)      
      modify(:revoke, ports, addresses, name)
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
    
    def get(name=nil)
      name ||= current_group_name
      Rudy::AWS::EC2::Groups.get name
    end
    
    def list
      Rudy::AWS::EC2::Groups.list
    end
    
  private 
    def modify(action, ports=nil, addresses=nil, name=nil)
      name ||= current_group_name
      addresses ||= [Rudy::Utils::external_ip_address]
      
      if ports.nil?
        ports = current_machine_os.to_s == 'windows' ? [3389,22] : [22]
      else
        ports = [ports].flatten.compact
      end
      
      ports.each do |port|
        li "#{action} port #{port} access for: #{addresses.join(', ')}"
        Rudy::AWS::EC2::Groups.send(action, name, addresses, [[port, port]]) rescue nil
      end
    end
    
  end
end; end; end