

library :rudy, 'lib'
group "Metadata"

tryout "Rudy::Machines API" do
  
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
    Rudy::Machine.new('07').save
    Rudy::Machine.new('08').save
    Rudy::Machine.new('09').save
  end
  
  clean do
    Rudy::Machine.new('07').destroy
    Rudy::Machine.new('08').destroy
    Rudy::Machine.new('09').destroy
    if Rudy.debug?
      puts $/, "Rudy Debugging:"
      Rudy::Huxtable.logger.rewind
      puts Rudy::Huxtable.logger.read unless Rudy::Huxtable.logger.closed_read?
    end
  end
  
  dream :class, Rudy::Machine
  drill "get machine metadata" do
    Rudy::Machines.get '07'
  end
  
  drill "knows when the current group is not running", false do
    Rudy::Machines.running?
  end

end