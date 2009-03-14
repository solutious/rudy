
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
      lines = ["%12s: %s" % ['GROUP', self.name.att(:bright)]]
      
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
end