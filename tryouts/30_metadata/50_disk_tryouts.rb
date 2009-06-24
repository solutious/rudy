rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "Metadata"

test_domain = 'test_' #<< Rudy::Utils.strand
test_env = 'env_' << Rudy::Utils.strand

tryout "Disk API" do
  
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    global.environment = test_env
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @@sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  xdrill "can create test domain (#{test_domain})" do
    @@sdb.create_domain test_domain
  end
  
  xdrill "can set test domain" do
    disk = new_disk '/', test_env
    disk.sdb_domain = test_domain
    disk.sdb_domain
  end
  
  drill "name a disk properly" do
    tmp  = [Rudy::Huxtable.global.zone, test_env]
    tmp += [Rudy::Huxtable.global.role, Rudy::Huxtable.global.position]
      # disk-us-east-1b-env_xxxxxx-app-01-rudy-disk
    dream ['disk', tmp, 'sergeant', 'disk'].join(Rudy::DELIM)
    
    disk = Rudy::MetaData::Disk.new('/sergeant/disk', 1, '/dev/sds')    
    disk.name
  end
  
  dream [1, '/dev/sdh', '/']
  drill "has a default size and device" do
    disk = Rudy::MetaData::Disk.new('/')
    [disk.size, disk.device, disk.path]
  end
  
  dream nil, 1, "wrong number of arguments (0 for 1)"
  drill "will fail if given no path" do
    Rudy::MetaData::Disk.new
  end
  
  
  xdrill "save disk metadata" do
    Rudy::Disk.new(path, 1, '/dev/sds').save
  end
  
  xdrill "won't save over a disk with the same name" do
    new_disk('/sergeant/disk', test_env).save
  end
  
  xdrill "create disk instance with volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.create
    stash :awsid, disk.awsid
  end
  
  xdrill "refresh disk" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.refresh
    disk.awsid
  end
  
  xdrill "knows about the state of the volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.refresh
    [disk.exists?, disk.attached?, disk.in_use?]
  end
  
  xdrill "destroy disk with volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.update
    disk.destroy
  end
  
  xdrill "destroy a domain (#{test_domain})" do
    @@sdb.destroy_domain test_domain
  end
  
end


