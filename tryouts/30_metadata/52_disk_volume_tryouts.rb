group "Metadata"
library :rudy, 'lib'

tryout "Disk Volume API" do
  
  set :test_domain, 'test_' #<< Rudy::Utils.strand(4)
  set :test_env, 'env_' << Rudy::Utils.strand(4)
  
  setup do
    Rudy.enable_debug
    Rudy::Huxtable.global.offline = true
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    global.environment = test_env
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
  end
  
  clean do
    if Rudy.debug?
      puts $/, "Rudy Debugging:"
      Rudy::Huxtable.logger.rewind
      puts Rudy::Huxtable.logger.read
    end
  end
  
  dream :volid, nil
  drill "disk volid is nil by default" do
    Rudy::Disk.new '/any/path'
  end
  
  dream :nil?, false
  dream :class, String
  drill "can create volume" do
    d = Rudy::Disk.new('/any/path', :size => 3)
    d.create
    d.volid
  end
  
  xdrill "can attach volume to instance"
  xdrill "can mount volume"
  xdrill "can detach volume from instance"
  
  drill "can destroy volume" do
    
  end
  
end