
group "Metadata"
library :rudy, 'lib'

tryout "Disk API" do
  
  set :test_domain, Rudy::DOMAIN #'test_' << Rudy::Utils.strand(4)
  set :test_env, 'stage' #'env_' << Rudy::Utils.strand(4)
  
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
  
  xdrill "can create test domain", test_domain do
    Rudy::Metadata.create_domain test_domain
  end
  
  
  dream :class, Rudy::Disk
  dream :name do
    tmp  = [Rudy::Huxtable.global.zone, Rudy::Huxtable.global.environment]
    tmp += [Rudy::Huxtable.global.role, '01']
      # disk-us-east-1b-env_xxxxxx-app-01-rudy-disk
    ['disk', tmp].join(Rudy::DELIM)
  end
  drill "can create disk object for root path" do
    Rudy::Disk.new('/')
  end
  
  dream :name do
    tmp  = [Rudy::Huxtable.global.zone, Rudy::Huxtable.global.environment]
    tmp += [Rudy::Huxtable.global.role, '01']
      # disk-us-east-1b-env_xxxxxx-app-01-any-path
    ['disk', tmp, 'any', 'path'].join(Rudy::DELIM)
  end
  drill "can create disk object for an arbitrary path" do
    Rudy::Disk.new('/any/path')
  end
  
  dream :size, 1
  dream :device, '/dev/sdh'
  dream :path, '/'
  drill "has a default size and device" do
    Rudy::Disk.new('/')
  end
  
  dream :path, '/anything'
  dream :position, '09'
  drill "can specify a position" do
    Rudy::Disk.new '09', '/anything' 
  end
  
  drill "save disk metadata", true do
    ret = Rudy::Disk.new('/any/path').save
    sleep 1 # eventual consistency
    ret
  end
  
  drill "knows when an object exists", true do
    Rudy::Disk.new('/any/path').exists?
  end
  
  drill "knows when an object doesn't exist", false do
    Rudy::Disk.new('/no/such/disk').exists?
  end
  
  dream :exception, Rudy::Metadata::DuplicateRecord
  drill "won't save over a disk with the same name" do
    Rudy::Disk.new('/any/path').save
  end
  
  drill "will save over a disk with the same name if forced", true do
    Rudy::Disk.new('/any/path').save(:replace)
  end
  
  dream :class, Rudy::Disk
  drill "get disk metadata" do
    Rudy::Disks.get '/any/path'
  end
  
  dream :class, Rudy::Disk
  dream :mounted, false
  drill "refresh disk metadata" do
    d = Rudy::Disk.new('/any/path')
    d.mounted = true
    d.refresh!
    d
  end
  
  dream true
  drill "destroy disk metadata" do
    d = Rudy::Disk.new('/any/path')
    d.destroy
  end
  
  xdrill "destroy a domain (#{test_domain})" do
    Rudy::Metadata.destroy_domain test_domain
  end
  
end


