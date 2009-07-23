
library :rudy, 'lib'
group "Metadata"

tryout "Rudy::Machine API" do
  
  set :test_domain, Rudy::DOMAIN #'test_' << Rudy::Utils.strand(4)
  set :test_env, 'stage' #'env_' << Rudy::Utils.strand(4)

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
  
  dream :class, Rudy::Machine
  dream :position, '02'
  drill "create new machine instance" do
    Rudy::Machine.new '02'
  end

  drill "save machine metadata", true do
    Rudy::Machine.new.save
  end
  
  drill "knows when an object exists", true do
    Rudy::Machine.new.exists?
  end
  
  drill "knows when an object doesn't exist", false do
    Rudy::Machine.new('99').exists?
  end
  
  dream :exception, Rudy::Metadata::DuplicateRecord
  drill "won't save over a machine with the same name" do
    Rudy::Machine.new.save
  end
  
  drill "will save over a disk with the same name if forced", true do
    Rudy::Machine.new.save(:replace)
  end
  
  dream :class, Rudy::Machine
  drill "get machine metadata" do
    Rudy::Machine.get '01'
  end
  
  dream :class, Rudy::Machine
  dream :available, false
  xdrill "refresh disk metadata" do
    d = Rudy::Machine.new
    d.available = true
    d.refresh
    d
  end
  
  drill "destroy machine metadata", true do
    Rudy::Machine.new.destroy
  end
  
  
end
