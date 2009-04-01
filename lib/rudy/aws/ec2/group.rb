
module Rudy::AWS
  
  class EC2::Group < Storable
    class Rule < Storable
      field :ports => Range          # Port range
      field :protocol => String
      def to_s
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
    
    # Print info about a a security group
    #
    # * +group+ is a Rudy::AWS::EC2::Group object
    def to_s
      lines = ["%12s: %s" % ['GROUP', self.name.bright]]
      
      (self.addresses || {}).each_pair do |address,rules|
        lines << "%6s %s:  %s" % ['', address.to_s, rules.collect { |p| p.to_s}.join(', ')]
      end
      
      (self.groups || {}).each_pair do |group,rules|
        lines << "%6s %s:  %s" % ['', group, rules.collect { |p| p.to_s}.join(', ') ]
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
  
  
  
  class EC2
    class Groups
      include Rudy::AWS::ObjectBase
  
      def list(group_names=[])
        group_names ||= []
        groups = list_as_hash(group_names)
        groups &&= groups.values
        groups
      end
      
      # * +group_names+ is a list of security group names to look for. If it's empty, all groups
      # associated to the account will be returned.
      #
      # Returns an Array of Rudy::AWS::EC2::Group objects
      def list_as_hash(group_names=[])
        group_names ||= []
        glist = @aws.describe_security_groups(:group_name => group_names) || {}
        return unless glist['securityGroupInfo'].is_a?(Hash)
        groups = {}
        glist['securityGroupInfo']['item'].each do |oldg| 
          g = Groups.from_hash(oldg)
          groups[g.name] = g
        end
        groups
      end
      
      def any?
        groups = list || []
        !groups.empty?
      end
      
      # Create a new EC2 security group
      # Returns true/false whether successful
      def create(name, desc=nil)
        ret = @aws.create_security_group(:group_name => name, :group_description => desc || "Group #{name}")
        return false unless (ret && ret['return'] == 'true')
        get(name)
      end
    
      # Delete an EC2 security group
      # Returns true/false whether successful
      def destroy(name)
        ret = @aws.delete_security_group(:group_name => name)
        (ret && ret['return'] == 'true')
      end
    
      # * +name+ a string
      def get(name)
        (list([name]) || []).first
      end
    
      # +group+ a Rudy::AWS::EC2::Group object
      #def save(group)
      #  
      #end
    
      def modify_rules(meth, name, from_port, to_port, protocol='tcp', ipa='0.0.0.0/0')
        opts = {
          :group_name => name,
          :ip_protocol => protocol,
          :from_port => from_port,
          :to_port => to_port,
          :cidr_ip => ipa
        }
        
        ret = @aws.send("#{meth}_security_group_ingress", opts)
        (ret && ret['return'] == 'true')
      end
      private :modify_rules
    
      def modify_group_rules(meth, name, gname=nil, gowner=nil)
        opts = {
          :group_name => name,
          :source_security_group_name => gname,
          :source_security_group_owner_id => gowner
        }
        ret = @aws.send("#{meth}_security_group_ingress", opts)
        (ret && ret['return'] == 'true')
      end
      private :modify_group_rules
      
      # Authorize a port/protocol for a specific IP address
      def authorize(*args)
        modify_rules(:authorize, *args)
      end
      alias :authorise :authorize
      
      def authorize_group(*args)
        modify_group_rules(:authorize, *args)
      end
      alias :authorise_group :authorize_group
      
      def revoke_group(*args)
        modify_group_rules(:revoke, *args)
      end
      
      # Revoke a port/protocol for a specific IP address
      # Takes the same arguments as authorize
      def revoke(*args)
        modify_rules(:revoke, *args)
      end
      
    
      # Does the security group +name+ exist?
      def exists?(name)
        begin
          g = list([name.to_s])
        rescue ::EC2::InvalidGroupNotFound
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
              name = "#{olda['cidrIp']}/#{oldp['ipProtocol']}"
              newg.add_address(name, newp)   # ipaddress/mask/protocol
            end
          end
        end
        newg
      end
    
    end
  end

end