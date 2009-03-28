
module Rudy::AWS
  
  class EC2::Group < Storable
    class Permissions < Storable
      field :addresses => Array      # IPAddr
      field :groups => Array         # String
      field :ports => Range          # Port range
      field :protocol => String
    end      
  end
  
  class EC2::Group < Storable
    field :name => String
    field :description => String
    field :owner_id => String
    field :permissions => Array  # Rudy::AWS::EC2::Group::Permissions
    
    # Print info about a a security group
    # +group+ is a Rudy::AWS::EC2::Group object
    def to_s
      lines = ["%12s: %s" % ['GROUP', self.name.bright]]
      
      (self.permissions || []).each do |perm|
        lines << "%6s %5s:%-5s (%s):" % ['', perm.ports.first, perm.ports.last, perm.protocol]
        lines << (perm.addresses || perm.groups || []).sort.collect { |item| sprintf("%12s %-30s", '', item) }
        lines << nil
      end
      lines.join($/)
    end
    
    # +perm+ is a Permissions object
    def add_permission(perm)
      return false unless perm.is_a?(Permissions)
      (@permissions ||= []) << perm
      perm
    end
    
  end
  
  
  
  class EC2::Groups
    include Rudy::AWS::ObjectBase
  
    
    # +group_names+ is a list of security group names to look for. If it's empty, all groups
    # associated to the account will be returned.
    # Returns an Array of Rudy::AWS::EC2::Group objects
    def list(group_names=[])
      glist = @aws.describe_security_groups(:group_name => group_names) || {}
      return unless glist['securityGroupInfo'].is_a?(Hash)
      groups = glist['securityGroupInfo']['item'].collect do |oldg| 
        Groups.from_hash(oldg)
      end
      groups
    end
    
    # Create a new EC2 security group
    # Returns true/false whether successful
    def create(name, desc=nil)
      @aws.create_security_group(:group_name => name, :group_description => desc || "Group #{name}")
    end
    
    # Delete an EC2 security group
    # Returns true/false whether successful
    def destroy(name)
      @aws.delete_security_group(:group_name => name)
    end
    
    # +name+ a string
    def get(name)
      (list([name]) || []).first
    end
    
    # +group+ a Rudy::AWS::EC2::Group object
    #def save(group)
    #  
    #end
    
    def modify(meth, name, from_port, to_port, protocol='tcp', ipa='0.0.0.0/0', gname=nil, gowner=nil)
      opts = {
        :group_name => name,
        :ip_protocol => protocol,
        :from_port => from_port,
        :to_port => to_port,
        :cidr_ip => ipa,
        :source_security_group_name => gname,
        :source_security_group_owner_id => gowner
      }
      @aws.send("#{meth}_security_group_ingress", opts)
    end
    private :modify
    
    # Authorize a port/protocol for a specific IP address
    def authorize(*args)
      modify(:authorize, *args)
    end
    alias :authorise :authorize
    
    # Revoke a port/protocol for a specific IP address
    # Takes the same arguments as authorize
    def revoke(*args)
      modify(:revoke, *args)
    end
      
    
    # Does the security group +name+ exist?
    def exists?(name)
      begin
        g = list([name.to_s])
      rescue
        return false
      end
      
      !g.empty?
    end
    
    
    
    
    # +oldg+ is an EC2::Base Security Group Hash. This is the format
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
    def self.from_hash(oldg)
      newg = Rudy::AWS::EC2::Group.new
      newg.name = oldg['groupName']
      newg.description = oldg['groupDescription']
      newg.owner_id = oldg['ownerId']
      return newg unless oldg['ipPermissions'].is_a?(Hash)
      newg.permissions = oldg['ipPermissions']['item'].collect do |oldp|
        newp = Rudy::AWS::EC2::Group::Permissions.new
        newp.ports = Range.new(oldp['fromPort'], oldp['toPort'])
        newp.protocol = oldp['ipProtocol']
        if oldp['groups'].is_a?(Hash)
          newp.groups = oldp['groups']['item'].collect do |oldpg|
            [oldpg['userId'], oldpg['groupName']].join(':')   # account_num:name
          end
        end
        if oldp['ipRanges'].is_a?(Hash)
          newp.addresses = oldp['ipRanges']['item'].collect do |olda|
            olda['cidrIp']
          end
        end
        newp
      end
      newg
    end
    
    
  end

end