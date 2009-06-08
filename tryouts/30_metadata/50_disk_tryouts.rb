rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "Metadata"

test_domain = 'test_' #<< Rudy::Utils.strand
test_env = 'env_' << Rudy::Utils.strand

tryout "Disk API" do
  
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @@sdb = Rudy::AWS::SDB.new(akey, skey, region)
    def new_disk(path, env)
      disk = Rudy::MetaData::Disk.new(path, 1, '/dev/sds')
      disk.environment = env
      disk
    end
  end
  
  xdrill "can create test domain (#{test_domain})" do
    @@sdb.create_domain test_domain
  end
  
  drill "can set test domain" do
    disk = new_disk '/', test_env
    disk.sdb_domain = test_domain
    disk.sdb_domain
  end
  
  drill "create disk instance" do
    disk = new_disk '/sergeant/disk', test_env
    tmp  = [Rudy::Huxtable.global.zone, test_env]
    tmp += [Rudy::Huxtable.global.role, Rudy::Huxtable.global.position]
    # disk-us-east-1b-env_z6253g-app-01-rudy-disk
    disk_name = ['disk', tmp, 'sergeant', 'disk'].join(Rudy::DELIM)
    stash :expected, disk_name
    stash :actual, disk.name
    [disk_name == disk.name, disk.valid?]
  end
  
  drill "save disk" do
    new_disk('/sergeant/disk', test_env).save
  end
  
  xdrill "won't save over a disk with the same name" do
    new_disk('/sergeant/disk', test_env).save
  end
  
  drill "create disk instance with volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.create
    stash :awsid, disk.awsid
  end
  
  drill "refresh disk" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.refresh
    disk.awsid
  end
  
  drill "knows about the state of the volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.refresh
    [disk.exists?, disk.attached?, disk.in_use?]
  end
  
  drill "destroy disk with volume" do
    disk = new_disk('/sergeant/disk', test_env)
    disk.update
    disk.destroy
  end
  
  xdrill "destroy a domain (#{test_domain})" do
    @@sdb.destroy_domain test_domain
  end
  
end

tryout "Disk API" do
  dream "can create test domain (#{test_domain})", true
  dream "can set test domain", test_domain
  dream "create disk instance", [true, true]
  dream "save disk", true
  dream "won't save over a disk with the same name" do
    rcode 1
    output false
  end
  dream "refresh disk", String, :class
  dream "knows about the state of the volume", ''
  dream "create disk instance with volume", String, :class
  dream "knows about the state of the volume", [true, false, false]
  dream "destroy disk with volume", true
  dream "destroy a domain (#{test_domain})", true
end


