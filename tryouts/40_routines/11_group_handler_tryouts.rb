group "Routines"
library :rudy, 'lib'
  
tryout "Group Handler" do
  set :group, 'grp-' << Rudy::Utils.strand(4)
  set :global, Rudy::Huxtable.global
  set :config, Rudy::Huxtable.config
  set :test_env, 'env_' << Rudy::Utils.strand
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
    global.environment = test_env
  end

  drill "knows when a group doesn't exist", false do
    Rudy::Routines::Handlers::Group.exists? group
  end
  
  dream :class, Rudy::AWS::EC2::Group
  drill "create a group (#{group})" do
    Rudy::Routines::Handlers::Group.create group
  end
  
  drill "knows when a group exists", true do
    Rudy::Routines::Handlers::Group.exists? group
  end
  
  dream true
  drill "destroy group" do
    Rudy::Routines::Handlers::Group.destroy group
  end
  
end