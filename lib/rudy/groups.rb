

module Rudy
  class Groups
    include Rudy::Huxtable
   
   
    def create(name, description=nil, opts={})
      name ||= current_machine_group
      description ||= 
      raise "Group #{name} already exists" if @ec2.groups.exists?(name)
      @ec2.groups.create(name, description)
      authorize(name, opts)
    end
    
    def destroy(name)
      name ||= current_machine_group
      raise "Group #{name} does not exist" unless @ec2.groups.exists?(name)
      @ec2.groups.destroy(name)
    end
    
    def exists?(name)
      g = list(:name => name)
      (g && !g.empty?)
    end
    
    def list(name=nil)
      filter = name ? [name] : []
      @ec2.groups.list(filter)
    end
    
    def authorize(name, opts={})
      modify_permissions(:authorize, name, opts)
    end
    def revoke(name, opts={})
      modify_permissions(:revoke, name, opts)
    end
    
    def modify_permissions(action, name, opts)
      name ||= current_machine_group
      
      raise "You must supply a group name" unless name
      raise "Group does not exist" unless @ec2.groups.exists?(name)
      @logger.puts "#{action.to_s.capitalize} access for #{opts[:name].bright}"
      
      if opts[:group] || opts[:owner]
        opts = { 
          :owner => @config.awsinfo.account,
        }.merge(opts)
        
        raise "Owner not specified." unless opts[:owner]
         
        if opts[:addresses] || opts[:ports] || opts[:protocol]
          raise "You cannot supply a port or IP address when you supply a group/owner"
        end
         
        raise "You must supply a group name" unless opts[:group]
        raise "You must supply an owner ID" unless opts[:owner]
         
        @ec2.groups.send("#{action}_group", opts[:name], opts[:owner], opts[:group])
      else
        opts[:ports] ||= [[22,22],[80,80],[443,443]]
        opts[:protocols] ||= ["tcp"]          
        opts[:addresses] ||= [Rudy::Utils::external_ip_address]
         
        # Make sure the IP addresses have ranges
        opts[:addresses].collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32"  }
        
        opts[:protocols].each do |protocol|
          opts[:addresses].each do |address|
            opts[:ports].each do |port|
              @logger.puts "Ports #{port[0]}:#{port[1]} (#{protocol}) for #{opts[:addresses].join(', ')}"
              @ec2.groups.send(action, opts[:name], port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
            end
          end
        end

      end
     
    end
  end
end