rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Require-time"
library :rudy, rudy_lib_path

tryout "Initialization of Global" do
  global = Rudy::Huxtable.global
  drill "has global", global, :class, Rudy::Global
  drill "has default region", global.region, :'us-east-1'
  drill "has default zone", global.zone, :'us-east-1b'
  drill "has default environment", global.environment, :stage
  drill "has default role", global.role, :app
  drill "default position is nil", global.position, nil
  drill "default user is nil", global.user, nil
end

tryout "Global knows ENV" do
  
  dream 'ACCESS99'
  drill "reads AWS_ACCESS_KEY" do
    ENV['AWS_ACCESS_KEY'] = 'ACCESS99' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.accesskey
  end
  
  dream 'SECRET33'
  drill "reads AWS_SECRET_KEY before AWS_SECRET_ACCESS_KEY" do
    ENV['AWS_SECRET_ACCESS_KEY'] = 'SACCESS7'
    ENV['AWS_SECRET_KEY'] = 'SECRET33' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.secretkey
  end
  
  dream 'SACCESS7'
  dream :class, String
  drill "reads AWS_SECRET_ACCESS_KEY" do
    ENV['AWS_SECRET_ACCESS_KEY'] = 'SACCESS7'
    ENV['AWS_SECRET_KEY'] = nil or Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.secretkey
  end
  
  dream File.expand_path('CERT22')
  drill "reads EC2_CERT" do
    ENV['EC2_CERT'] = 'CERT22' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.cert
  end
  
  dream File.expand_path('PK100')
  drill "reads EC2_PRIVATE_KEY" do
    ENV['EC2_PRIVATE_KEY'] = 'PK100' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.pkey
  end

end

tryout "Population of Global" do
  setup do
    Rudy::Huxtable.update_config
  end
end
