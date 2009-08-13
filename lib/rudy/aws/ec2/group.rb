
module Rudy::AWS
  
  class EC2::Group < Storable
    class Rule < Storable
      field :ports => Range          # Port range
      field :protocol => String
      
      def to_s(with_title=false)
        if self.ports.first == self.ports.last
          "%s(%s)" % [self.protocol, self.ports.last]
        else
          "%s(%s..%s)" % [self.protocol, self.ports.first, self.ports.last]
        end
      end
    end     
  end
  
  class EC2::Group < Storable
    field :name => String
    field :description => String
    field :owner_id => String
    field :addresses => Hash         # key: address/mask, value Array of Rule object
    field :groups => Hash            # key: group, value Array of Rule object
    
    
    def liner_note
      info = "(authorized accounts: #{@groups.keys.join(', ')})" 
      info = '' if @groups.empty?
      "%s %s" % [@name.bright, info]
    end
    
    
    # Print info about a security group
    #
    # * +group+ is a Rudy::AWS::EC2::Group object
    def to_s(with_title=false)
      lines = [liner_note]
      (self.addresses || {}).each_pair do |address,rules|
        lines << "%18s -> %s" % [address.to_s, rules.collect { |p| p.to_s}.join(', ')]
      end
      lines.join($/)
    end
    
    def pretty
      lines = [@name.bright]
      field_names.each do |key|
        next unless self.respond_to?(key)
        next if [:addresses, :groups].member?(key)
        val = self.send(key)
        lines << sprintf(" %12s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      @addresses.each_pair do |a,r|
        rules = r.collect { |r| r.to_s }.join(', ') if r
        lines << sprintf(" %12s: %s (%s)", 'address', a.to_s, rules)
      end
      @groups.each_pair do |g,r|
        rules = r.collect { |r| r.to_s }.join(', ')
        lines << sprintf(" %12s: %s (%s)", 'group', g.to_s, rules)
      end
      lines.join($/)
    end

    
    # * +ipaddress+ is a String, ipaddress/mask/protocol
    # * +rule+ is a Rule object
    def add_address(ipaddress, rule)
      return false unless rule.is_a?(Rule)
      @addresses ||= {}
      (@addresses[ipaddress] ||= []) << rule
      rule
    end
    
    # * +group+ is a String, accountnum:group
    # * +rule+ is a Rule object
    def add_group(group, rule)
      return false unless rule.is_a?(Rule)
      @groups ||= {}
      (@groups[group] ||= []) << rule
    end
    
  end
  
  
  
  module EC2
    module Groups
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
  
      # Create a new EC2 security group
      # Returns list of created groups
      def create(name, desc=nil, addresses=[], ports=[], protocols=[], &each_group)
        desc ||= "Security Group #{name}"
        ret = @@ec2.create_security_group(:group_name => name, :group_description => desc)
        return false unless (ret && ret['return'] == 'true')
        authorize(name, addresses, ports, protocols)
        get(name, &each_group)
      end
    
      # Delete an EC2 security group
      # Returns true/false whether successful
      def destroy(name, &each_group)
        list(name, &each_group) if each_group
        ret = @@ec2.delete_security_group(:group_name => name)
        (ret && ret['return'] == 'true')
      end
      
      # Authorize a port/protocol for a specific IP address
      def authorize(name, addresses=[], ports=[], protocols=[], &each_group)
        modify_rules(:authorize, name, addresses, ports, protocols, &each_group)
      end
      alias :authorise :authorize
      
      # Revoke a port/protocol for a specific IP address
      # Takes the same arguments as authorize
      def revoke(name, addresses=[], ports=[], protocols=[], &each_group)
        modify_rules(:revoke, name, addresses, ports, protocols, &each_group)
      end
      
      def authorize_group(name, gname, owner, &each_group)
        modify_group_rules(:authorize, name, gname, owner, &each_group)
      end
      alias :authorise_group :authorize_group
      
      def revoke_group(name, gname, owner, &each_group)
        modify_group_rules(:revoke, name, gname, owner, &each_group)
      end
      
      def list(group_names=[], &each_group)
        group_names ||= []
        groups = list_as_hash(group_names, &each_group)
        groups &&= groups.values
        groups
      end
      
      # * +group_names+ is a list of security group names to look for. If it's empty, all groups
      # associated to the account will be returned.
      #
      # Returns an Array of Rudy::AWS::EC2::Group objects
      def list_as_hash(group_names=[], &each_group)
        group_names = [group_names].flatten.compact
        glist = @@ec2.describe_security_groups(:group_name => group_names) || {}
        return unless glist['securityGroupInfo'].is_a?(Hash)
        groups = {}
        glist['securityGroupInfo']['item'].each do |oldg| 
          g = Groups.from_hash(oldg)
          groups[g.name] = g
        end
        groups.each_value { |g| each_group.call(g) } if each_group
        groups = nil if groups.empty?
        groups
      end
      
      def any?
        groups = list || []
        !groups.empty?
      end
      
      # * +name+ a string
      def get(name)
        (list([name]) || []).first
      end
    
      # +group+ a Rudy::AWS::EC2::Group object
      #def save(group)
      #  
      #end
    
      # Does the security group +name+ exist?
      def exists?(name)
        begin
          g = list([name.to_s])
        rescue ::AWS::InvalidGroupNotFound
          return false 
        end
      
        !g.empty?
      end
    
    
    
    
      # * +ghash+ is an EC2::Base Security Group Hash. This is the format
      # returned by EC2::Base#describe_security_groups
      #
      #      groupName: stage-app
      #      groupDescription: 
      #      ownerId: "207436219441"
      #      ipPermissions: 
      #        item: 
      #        - ipRanges: 
      #            item: 
      #            - cidrIp: 216.19.182.83/32
      #            - cidrIp: 24.5.71.201/32
      #            - cidrIp: 75.157.176.202/32
      #            - cidrIp: 84.28.52.172/32
      #            - cidrIp: 87.212.145.201/32
      #            - cidrIp: 96.49.129.178/32
      #          groups: 
      #            item: 
      #            - groupName: default
      #              userId: "207436219441"
      #            - groupName: stage-app
      #              userId: "207436219441"  
      #          fromPort: "22"
      #          toPort: "22"
      #          ipProtocol: tcp
      #
      # Returns a Rudy::AWS::EC2::Group object
      def self.from_hash(ghash)
        newg = Rudy::AWS::EC2::Group.new
        newg.name = ghash['groupName']
        newg.description = ghash['groupDescription']
        newg.owner_id = ghash['ownerId']
        newg.addresses = {}
        newg.groups = {}
        
        return newg unless ghash['ipPermissions'].is_a?(Hash)
        
        ghash['ipPermissions']['item'].each do |oldp|
          newp = Rudy::AWS::EC2::Group::Rule.new
          newp.ports = Range.new(oldp['fromPort'], oldp['toPort'])
          newp.protocol = oldp['ipProtocol']
          if oldp['groups'].is_a?(Hash)
            oldp['groups']['item'].each do |oldpg|
              name = [oldpg['userId'], oldpg['groupName']].join(':')   # account_num:name
              newg.add_group(name, newp)
            end
          end
          if oldp['ipRanges'].is_a?(Hash)
            oldp['ipRanges']['item'].each do |olda|
              name = "#{olda['cidrIp']}"
              newg.add_address(name, newp)   # ipaddress/mask/protocol
            end
          end
        end
        newg
      end
      
      
    private
      

      def modify_rules(meth, name, addresses, ports, protocols, &each_group)
        list(name, &each_group) if each_group
        
        ports = [[22,22],[80,80],[443,443]] if !ports || ports.empty?
        protocols = ["tcp"] if !protocols || protocols.empty?
        addresses = [Rudy::Utils::external_ip_address] if !addresses || addresses.empty?
        
        # Make sure the IP addresses have ranges
        addresses.collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32" }
        protocols.collect! { |p| p.to_s }
        ret = false
        protocols.each do |protocol|
          addresses.each do |address|
            ports.each do |port|
              port_lo, port_hi = port.is_a?(Array) ? [port[0], port[1]] : [port, port]
              @logger.puts "#{meth} for ports #{port[0]}:#{port[1]} (#{protocol}) for #{addresses.join(', ')}" if @logger
              ret = modify_rule(meth, name, port[0].to_i, (port[1] || port[0]).to_i, protocol, address)
              raise "Unknown error during #{meth}" unless ret
            end
          end
        end
        
        ret
      end
      
      def modify_rule(meth, name, from_port, to_port, protocol, ipa)
        opts = {
          :group_name => name,
          :ip_protocol => protocol,
          :from_port => from_port,
          :to_port => to_port,
          :cidr_ip => ipa
        }
        ret = @@ec2.send("#{meth}_security_group_ingress", opts)
        (ret && ret['return'] == 'true')
      end
      
      
      def modify_group_rules(meth, name, gname, gowner, &each_group)
        list(name, &each_group) if each_group
        # probably works, needs to be tested
        #gowner &&= gowner.tr!('-', '') # Remove dashes from aws account number
        
        opts = {
          :group_name => name,
          :source_security_group_name => gname,
          :source_security_group_owner_id => gowner
        }
        ret = @@ec2.send("#{meth}_security_group_ingress", opts)
        (ret && ret['return'] == 'true')
      end

      
    
    end
  end

end