
group "Metadata"
library :rudy, 'lib'

tryout "Backup API" do
  
  set :sample_time, Time.now.utc
  set :test_domain, Rudy::DOMAIN #'test_' << Rudy::Utils.strand(4)
  set :test_env, :stage #'env_' << Rudy::Utils.strand(4)
  
  setup do
    #Rudy.enable_debug
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
  
  xdrill "can create test domain", test_domain do
    Rudy::Metadata.create_domain test_domain
  end
  
  dream :class, Rudy::Backup
  drill "can create an instance" do
    Rudy::Backup.new
  end
  
  dream :class, Rudy::Backup
  dream :name do
    global = Rudy::Huxtable.global
    tmp  = [global.zone, global.environment, global.role, '01']
    tmp += ['20090201', '0000', '00']
    ['back', tmp].join(Rudy::DELIM) 
  end
  drill "can create backup object for root path" do
    Rudy::Backup.new(1, '/', :created => Time.parse('2009-02-01'))
  end
  
  dream :class, Rudy::Backup
  dream :name do
    global = Rudy::Huxtable.global
    tmp  = [global.zone, global.environment, global.role, '01']
    tmp += ['any', 'path', '20090201', '0000', '00']
    ['back', tmp].join(Rudy::DELIM) 
  end
  drill "can create backup object for an arbitrary path" do
    Rudy::Backup.new(1, '/any/path', :created => Time.parse('2009-02-01'))
  end
  
  dream :user, Rudy.sysinfo.user
  drill "has a default user" do
    Rudy::Backup.new(1, '/')
  end
  
  dream :class, Time
  drill "has a default created time" do
    Rudy::Backup.new(1, '/').created
  end
  
  drill "save metadata", true do
    ret = Rudy::Backup.new(1, '/any/path', :created => sample_time).save
    sleep 1
    ret
  end
  
  drill "knows when an object exists", true do
    Rudy::Backup.new(1, '/any/path', :created => sample_time).exists?
  end
  
  drill "knows when an object doesn't exist", false do
    Rudy::Backup.new(1, '/no/such/disk', :created => sample_time).exists?
  end
  
  dream :class, Rudy::Disk
  drill "creates associated disk object" do
    Rudy::Backup.new(1, '/any/path', :created => sample_time).disk
  end
  
  dream :exception, Rudy::Backups::NoDisk
  drill "raises exception when disk doesn't exist" do
    Rudy::Backup.new(1, '/no/such/disk').create
  end
  
  drill "destroy all backups", false do
    Rudy::Backups.list.each { |b| b.destroy }
    Rudy::Backups.any?
  end
  
  xdrill "destroy a domain (#{test_domain})", true do
    Rudy::Metadata.destroy_domain test_domain
  end
end