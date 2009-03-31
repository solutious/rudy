

module Rudy
  class Groups
    include Rudy::Huxtable
   
   
    def create(n=nil, description=nil, opts={})
      n ||= name(n)
      description ||= "Machine group #{n}"
      raise "Group #{n} already exists" if @@ec2.groups.exists?(n)
      @@ec2.groups.create(n, description)
      authorize(n, opts)
    end
    
    def destroy(n=nil)
      n ||= name(n)
      raise "Group #{n} does not exist" unless @@ec2.groups.exists?(n)
      @@ec2.groups.destroy(n)
    end
    
    def exists?(n=nil)
      n ||= name(n)
      @@ec2.groups.exists?(n)
    end
    
    def name(n=nil)
      n || current_machine_group
    end
    
    
    # Do any groups exist? The default group is not considered here since it
    # cannot be destroyed. We're interested in any other groups. 
    def any?
      groups = @@ec2.groups.list_as_hash
      return false unless groups
      groups.reject! { |name,g| g.name == 'default' }
      !groups.empty?
    end
    
    def list(n=nil, &each_object)
      n &&= [n]
      groups = @@ec2.groups.list(n)
      groups.each { |g| each_object.call(g) } if each_object
      groups
    end
    
    def list_as_hash(n=nil, &each_object)
      n &&= [n]
      groups = @@ec2.groups.list_as_hash(n)
      groups.each_pair { |n,g| each_object.call(g) } if each_object
      groups
    end
    
    def authorize(n, opts={})
      modify_permissions(:authorize, n, opts)
    end
    def revoke(n, opts={})
      modify_permissions(:revoke, n, opts)
    end
    
    # TODO: Consider changing the hash interface into arguments. 
    # with different methods for authorizing groups and addresses
    def modify_permissions(action, n, opts={})
      n ||= name(n)
      
      raise "You must supply a group name" unless n
      raise "Group does not exist" unless @@ec2.groups.exists?(n)
      @logger.puts "#{action.to_s.capitalize} access for #{n.bright}"
      

      opts[:ports] ||= [[22,22],[80,80],[443,443]]
      opts[:protocols] ||= ["tcp"]          
      opts[:addresses] ||= [Rudy::Utils::external_ip_address]
       
      # Make sure the IP addresses have ranges
      opts[:addresses].collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32"  }
      
      opts[:protocols].each do |protocol|
        opts[:addresses].each do |address|
          opts[:ports].each do |port|
            @logger.puts "Ports #{port[0]}:#{port[1]} (#{protocol}) for #{opts[:addresses].join(', ')}"
            @@ec2.groups.send(action, n, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
          end
        end
      end
      
      @@ec2.groups.get(n)
    
     
    end
    
    def modify_group_permissions(n=nil, group=nil, owner=nil)
      n ||= name(n)
      
      owner ||= @config.awsinfo.account
      
      raise "You must supply a group name" unless n
      raise "Group does not exist" unless @@ec2.groups.exists?(n)
      raise "Owner to authorize not specified" unless owner
      raise "Group to authorize not specified" unless owner
      
      @logger.puts "#{action.to_s.capitalize} access for #{n.bright}"

      @@ec2.groups.send("#{action}_group", n, group, owner)

      @@ec2.groups.get(n)
    end
    
  end
end