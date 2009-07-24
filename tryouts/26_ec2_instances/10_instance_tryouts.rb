group "EC2 Instances"
library :rudy, 'lib'

tryouts "Instances" do
  set :global, Rudy::Huxtable.global
  set :config, Rudy::Huxtable.config
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
    @ami = config.machines.find(global.region, :ami)
  end
  clean do
    Rudy::AWS::EC2::Addresses.list.each do |add|
      Rudy::AWS::EC2::Addresses.destroy add.ipaddress
    end
  end
  
  dream :class, String
  dream :empty?, false
  drill("has ami") { @ami }
  
  drill "no machines running", false do
    Rudy::AWS::EC2::Instances.any? :running
  end
  
  dream :class, Rudy::AWS::EC2::Instance
  dream :running?, true
  drill "create instance" do
    list = Rudy::AWS::EC2::Instances.create :ami => @ami, :group => "default"
    list.each do |instance|
      Rudy::Utils.waiter {
        Rudy::AWS::EC2::Instances.running?(instance) 
      }
    end
    Rudy::AWS::EC2::Instances.get list.first.awsid
  end
  
  dream :class, Array
  dream [:running, :pending, :shutting_down, :terminated, :degraded]
  drill "have known states" do
    Rudy::AWS::EC2::Instances::KNOWN_STATES
  end
  
    dream :class, Array
    dream :empty?, false
  drill "list instances as Array" do
    Rudy::AWS::EC2::Instances.list :running
  end

    dream :class, Hash
    dream :empty?, false
  drill "list instances as Hash" do
    Rudy::AWS::EC2::Instances.list_as_hash :running
  end
  
  # NOTE: This drill will probably fail b/c console output takes 
  # a few minutes to become available. 
  dream :class, String
  dream :empty?, false
  xdrill "have console output" do
    inst = Rudy::AWS::EC2::Instances.list(:running).first
    Rudy::AWS::EC2::Instances.console inst.awsid
  end
  
  dream true
  
  drill "assign IP address to instance", true do
    address = Rudy::AWS::EC2::Addresses.create
    instance = Rudy::AWS::EC2::Instances.list(:running).first
    Rudy::AWS::EC2::Addresses.associate(address, instance)
    instance = Rudy::AWS::EC2::Instances.get instance.awsid
    stash :address, address.ipaddress
    stash :instance_ip, instance.dns_public
    address.ipaddress == IPSocket.getaddress(instance.dns_public)
  end
  
  xdrill "can unassign an IP address (TODO)" do
    
  end
  
  # NOTE: Restart is generally disabled until it checks that it's
  # unavailable and then comes available (there's no restart status)
  xdrill "restart instance (TODO)", true do
    instance = Rudy::AWS::EC2::Instances.list(:running).first
    Rudy::AWS::EC2::Instances.restart instance
  end
  
  dream :class, Rudy::AWS::EC2::Instance
  dream :shutting_down?, true
  drill "destroy instance" do
    instance = Rudy::AWS::EC2::Instances.list(:running).first
    Rudy::AWS::EC2::Instances.destroy instance
    instance = Rudy::AWS::EC2::Instances.get instance.awsid
  end
  
end

__END__

should "(99) destroy instance" do
  assert @ec2inst.any?(:running), "No instances running"
  instances = @ec2inst.list(:running) 
  return skip("No running instances") unless instances
  instances.each do |instance|
    assert @ec2inst.destroy(instance), "Did not destroy"
  end
end