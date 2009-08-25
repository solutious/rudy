
group "Metadata"
library :rudy, 'lib'

tryout "Backup Snapshot API" do
  
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
  
  dream :class, Rudy::Disk
  drill "Creates disk object with volume" do
    b = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    b.disk.create
  end
  
  dream :class, String
  dream :empty?, false
  drill "refreshes associated disk object" do
    b = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    b.disk.volid
  end
  
  dream :class, String
  dream :empty?, false
  drill "create backups with snapshot" do
    b = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    b.create
    b.snapid
  end
  
  dream :any?, true
  drill "knows when there's at least one backup" do
    Rudy::Backup.new(1, '/any/path')
  end
  
  dream :any?, false
  drill "knows when there are no backups" do
    Rudy::Backup.new(1, '/no/such/path')
  end
  
  drill "destroy disk", true do
    back = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    back.disk.destroy
  end
  
  xdrill "destroy backup", true do
    back = Rudy::Backup.new(1, '/any/path', :created => sample_time)
    back.destroy
  end
  
  drill "destroy all backups", false do
    Rudy::Backups.list.each { |b| b.destroy }
    Rudy::Backups.any?
  end
  
end