
group "Metadata"
library :rudy, 'lib'

tryout "Backup Snapshot API" do
  
  set :sample_time, Time.now.utc
  set :test_domain, Rudy::DOMAIN #'test_' << Rudy::Utils.strand(4)
  set :test_env, :stage #'env_' << Rudy::Utils.strand(4)
  
  setup do
    Rudy.enable_debug
    Rudy::Huxtable.global.offline = true
    Rudy::Huxtable.update_config          # Read config files
    global  =  Rudy::Huxtable.global
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
  
  dream :class, String
  dream :empty?, false
  drill "refreshes associated disk object" do
    d = Rudy::Disk.new(1, '/any/path')
    d.create
    b = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    b.save
    b.disk.volid
  end
  
  drill "destroy metadata", [true, true] do
    back = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    a = back.disk.destroy
    b = back.destroy
    [true, true]
  end
  
  
end