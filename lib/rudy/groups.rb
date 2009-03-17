

module Rudy
  class Groups
    include Rudy::Huxtable
   
   
    def create(opts={})
      opts = {
        :name => current_machine_group
      }.merge(opts)
      raise "Group already exists" if @ec2.groups.exists?(opts[:name])
      @ec2.groups.create(opts[:name])
      authorize(opts)
    end
    
    def destroy(opts={})
      opts = {
        :name => current_machine_group
      }.merge(opts)
      raise "Group #{opts[:name]} does not exist" unless @ec2.groups.exists?(opts[:name])
      @ec2.groups.destroy(opts[:name])
    end
    
    def list(opts={})
      opts = {
        :name => current_machine_group,
        :all => false
      }.merge(opts)
     
      filter = opts[:all] ? [] : opts.delete(:name)
      @ec2.groups.list(filter) || []
    end
    
    def authorize(opts={})
      modify_permissions(:authorize, opts)
    end
    def revoke(opts={})
      modify_permissions(:revoke, opts)
    end
    
    def modify_permissions(action, opts)
      opts = {
        :name => current_machine_group,
        :all => false
      }.merge(opts)
      
      raise "You must supply a group name" unless opts[:name]
      raise "Group does not exist" unless @ec2.groups.exists?(opts[:name])
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
         
        @ec2.groups.send(action, opts[:name], nil, nil, nil, nil, opts[:group], opts[:owner])
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