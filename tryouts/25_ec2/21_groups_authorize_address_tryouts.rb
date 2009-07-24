group "EC2"
library :rudy, 'lib'

tryouts "Groups Authorize Address" do
  set :global, Rudy::Huxtable.global
  set :group_name, 'grp-' << Rudy::Utils.strand
  set :protocols, ['tcp', 'udp']
  set :external_ip, Rudy::Utils::external_ip_address || '192.168.0.1/32'
  set :addresses, [external_ip]
  set :ports, [[3100,3150],[3200,3250]]
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
    Rudy::AWS::EC2::Groups.create group_name
  end
  clean do 
    Rudy::AWS::EC2::Groups.destroy group_name
  end
  
  drill "authorize group rules returns true", true do
    Rudy::AWS::EC2::Groups.authorize group_name, addresses, ports, protocols
  end
  
    dream :proc, lambda { |group|
      group.addresses.each_pair do |address,rules|
        return false unless rules.is_a? Array
        return false unless rules.size == 7
      end
      true
    }
  drill "group (#{group_name}) contains new rules" do
    stash :group, Rudy::AWS::EC2::Groups.get(group_name)
  end
    
  drill "revoke group rules returns true", true do
    Rudy::AWS::EC2::Groups.revoke(group_name, addresses, ports, protocols)
  end
  
    dream :proc, lambda { |group|
      group.addresses.each_pair do |address,rules|
        return false unless rules.is_a? Array
        return false unless rules.size == 3
      end
      true
    }
  drill "group does not contain new rules" do
    group = Rudy::AWS::EC2::Groups.get(group_name)
    stash :group, group 
    group
  end
  
  
end