group "EC2"
library :rudy, 'lib'

tryouts "Volumes" do
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::AWS::EC2.connect akey, skey, region
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

__END__

should "(00) not be existing volumes" do
  volume_hash = @ec2vol.list_as_hash
  volume_hash.reject! { |volid, vol| !vol.available? }
  stop_test !volume_hash.empty?, "Destroy the existing volumes"
end

should "(10) create volume" do 
  volume_size = 2
  volume = @ec2vol.create(volume_size, @@zone)
  assert volume.is_a?(Rudy::AWS::EC2::Volume), "Not a Volume"
  assert_equal @@zone, volume.zone, "Zone incorrect: #{volume.zone}"
  assert_equal volume_size.to_i, volume.size.to_i, "Size incorrect: #{volume.size}"
  assert volume.creating? || volume.available?, "Volume not creating or available (#{volume.status})"
end

should "(20) list volumes" do
  volume_list = @ec2vol.list
  assert volume_list.is_a?(Array), "Not an Array"
  assert volume_list.size > 0, "No Volumes in Array"

  volume_hash = @ec2vol.list_as_hash
  assert volume_hash.is_a?(Hash), "Not a Hash"
  assert volume_hash.keys.size > 0, "No Volumes in Hash"

  assert_equal volume_list.size.to_i, volume_hash.keys.size.to_i, "Hash and Array not equal size"
end

should "(50) destroy volumes" do
  assert @ec2vol.any?, "No volumes"
  volume_list = @ec2vol.list
  volume_list.each do |vol|
    next unless vol.available?
    assert @ec2vol.destroy(vol.awsid), "Not destroyed (#{vol.awsid})"
  end
end
