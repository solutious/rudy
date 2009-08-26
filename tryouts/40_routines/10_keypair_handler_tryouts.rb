group "Routines"
library :rudy, 'lib'
  
tryout "Keypair Handler" do
  Rudy::Huxtable.update_config          # Read config files
  
  set :user, Rudy::Utils.strand(4)
  set :keydir, '/tmp'
  set :global, Rudy::Huxtable.global
  set :config, Rudy::Huxtable.config
  set :test_env, 'env_' << Rudy::Utils.strand
  setup do
    #Rudy.enable_debug  
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
    global.environment = test_env
    config.defaults[:keydir] = keydir
  end
  
  drill "has new temporary ssh key directory", keydir do
    config.defaults[:keydir]
  end
  
  drill "knows when a keypair isn't registered", false do
    Rudy::Routines::Handlers::Keypair.registered? user
  end
  
  drill "knows when a private key file doesn't exist", false do
    Rudy::Routines::Handlers::Keypair.pkey? '/path/2/' << user
  end
  
  dream "#{keydir}/key-#{Rudy::Huxtable.global.zone}-#{test_env}-app-#{user}"
  drill "determine keypair path (#{user})" do
    ret = Rudy::Routines::Handlers::Keypair.pkey user
  end
  
  dream "#{keydir}/key-#{Rudy::Huxtable.global.zone}-#{test_env}-app"
  drill "determine root keypair path" do
    Rudy::Routines::Handlers::Keypair.pkey :root
  end
  
  dream :class, Rudy::AWS::EC2::Keypair
  drill "create a new keypair" do
    Rudy::Routines::Handlers::Keypair.create user
  end
  
  dream :class, Rudy::AWS::EC2::Keypair
  drill "create a new root keypair" do
    Rudy::Routines::Handlers::Keypair.create :root
  end
  
end