group "EC2"
library :rudy, 'lib'

tryouts "Volumes" do
  set :global, Rudy::Huxtable.global
  setup do
    Rudy::Huxtable.update_config
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
  end
  
  drill "no existing volumes", false do
    Rudy::AWS::EC2::Volumes.any? :available
  end
  
  dream :class, Rudy::AWS::EC2::Volume
  dream :size, 2
  dream(:zone) { Rudy::Huxtable.global.zone }
  dream :proc, lambda { |v| !v.awsid.nil? }
  drill "create a 2GB volume" do
    Rudy::AWS::EC2::Volumes.create 2, Rudy::Huxtable.global.zone
  end
  
  dream :class, Array
  dream :empty?, false
  drill "list available volumes" do
    Rudy::AWS::EC2::Volumes.list :available
  end
  
  dream :class, Hash
  dream :empty?, false
  drill "list available volumes as hash" do
    Rudy::AWS::EC2::Volumes.list_as_hash :available
  end
  
  dream :class, Rudy::AWS::EC2::Volume
  dream :size, 2
  dream :available?, true
  drill "get a specific volume" do
    volid = Rudy::AWS::EC2::Volumes.list(:available).first.awsid
    Rudy::AWS::EC2::Volumes.get volid
  end
  
  drill "destroy all volumes", false do
    volumes = Rudy::AWS::EC2::Volumes.list
    volumes.each do |vol|
      next unless vol.available?
      Rudy::AWS::EC2::Volumes.destroy(vol.awsid)
    end
    Rudy::AWS::EC2::Volumes.any? :available
  end
  
  
end
