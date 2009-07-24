group "EC2"
library :rudy, 'lib'

tryouts "Addresses" do
  set :global, Rudy::Huxtable.global
  set :group_name, 'grp-' << Rudy::Utils.strand
  set :group_desc, 'desc-' << group_name
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
  end
  
  drill "should not be existing addresses", false do
    Rudy::AWS::EC2::Addresses.any?
  end
  
  dream :class, Rudy::AWS::EC2::Address
  dream :proc, lambda { |a| a.ipaddress.size > 0 }
  drill "create address" do
    Rudy::AWS::EC2::Addresses.create
  end
  
  dream :class, Array
  dream :empty?, false
  drill "list addresses" do
    stash :address, Rudy::AWS::EC2::Addresses.list
  end
  
  dream :class, Hash
  dream :empty?, false
  drill "list addresses as Hash" do
    Rudy::AWS::EC2::Addresses.list_as_hash
  end
  
  drill "destroy all addresses", true do
    Rudy::AWS::EC2::Addresses.list.each do |a|
      Rudy::AWS::EC2::Addresses.destroy a
    end
    Rudy::AWS::EC2::Addresses.list.nil?
  end
  
end