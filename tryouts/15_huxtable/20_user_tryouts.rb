

group "Rudy::Huxtable"
library :rudy, 'lib'

tryout "User related methods" do
  set :user, Rudy::Utils.strand(4)
  set :keydir, '/tmp'
  set :global, Rudy::Huxtable.global
  set :config, Rudy::Huxtable.config
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    config.defaults[:keydir] = keydir
    Rudy::Huxtable.global.zone = 'us-east-1b'
    module Cousin
      extend Rudy::Huxtable
    end 
  end
  
  drill "knows current user", :root do
    Cousin.current_machine_user
  end
  
  drill "keypair path for current user", "#{keydir}/key-us-east-1b-stage-app" do
    Cousin.user_keypairpath
  end
  drill "keypair path for arbitrary user", "#{keydir}/key-us-east-1b-stage-app-#{user}" do
    Cousin.user_keypairpath user
  end
  drill "keypair path for root user", "#{keydir}/key-us-east-1b-stage-app" do
    Cousin.user_keypairpath :root
  end
  
  drill "keypair name for current user", "key-us-east-1b-stage-app" do
    Cousin.user_keypairname
  end
  drill "keypair name for arbitrary user", "key-us-east-1b-stage-app-#{user}" do
    Cousin.user_keypairname user
  end
  drill "keypair name for root user", "key-us-east-1b-stage-app" do
    Cousin.user_keypairname :root
  end
  

  
end