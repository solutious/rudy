group "Metadata"
library :rudy, 'lib'

tryout "Disk Volume API" do
  
  set :test_domain, 'test_' #<< Rudy::Utils.strand(4)
  set :test_env, 'stage' << Rudy::Utils.strand(4)
  
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.global.offline = true
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    global.environment = test_env
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
  end
  
  clean do
    if Rudy.debug?
      puts $/, "Rudy Debugging:"
      Rudy::Huxtable.logger.rewind
      puts Rudy::Huxtable.logger.read unless Rudy::Huxtable.logger.closed_read?
    end
  end
  
  dream :volid, nil
  drill "disk volid is nil by default" do
    Rudy::Disk.new '/any/path'
  end
  
  dream :nil?, false
  dream :class, String
  drill "create disk instance with volume" do
    disk = Rudy::Disk.new '/sergeant/disk'
    disk.create
    disk.volid
  end
  
  dream :nil?, false
  drill "refresh disk" do
    disk = Rudy::Disk.new '/sergeant/disk'
    disk.refresh!
    disk.volid
  end
  
  xdrill "can attach volume to instance"
  xdrill "can mount volume"
  xdrill "can detach volume from instance"
  
  dream [true, false, false]
  drill "knows about the state of the volume" do
    disk = Rudy::Disk.new '/sergeant/disk'
    disk.refresh!
    [disk.volume_exists?, disk.volume_attached?, disk.volume_in_use?]
  end
  
  dream true
  drill "destroy disk with volume" do
    disk = Rudy::Disk.new '/sergeant/disk'
    disk.refresh!
    disk.destroy
  end
  
  
  
end