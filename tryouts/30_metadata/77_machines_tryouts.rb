

library :rudy, 'lib'
group "Metadata"

tryout "Rudy::Machines API" do
  
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
  drill "get machine metadata" do
    Rudy::Machines.get '01'
  end
end