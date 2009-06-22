rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Require-time"
library :rudy, rudy_lib_path

tryout "Initialization of Global" do
  global = Rudy::Huxtable.global
  drill "has global", global
  drill "has default region", global.region
  drill "has default zone", global.zone
  drill "has default environment", global.environment
  drill "has default role", global.role
  drill "has default position", global.position
  drill "has default user", global.user
end
dreams "Initialization of Global" do
  dream "has global", Rudy::Global, :class
  dream "has default region", :'us-east-1'
  dream "has default zone", :'us-east-1b'
  dream "has default environment", :stage
  dream "has default role", :app
  dream "has default position", '01'
  dream "has default user", :rudy
end

tryout "Global knows ENV" do
  drill "reads AWS_ACCESS_KEY" do
    ENV['AWS_ACCESS_KEY'] = 'ACCESS99' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.accesskey
  end
  drill "reads AWS_SECRET_KEY before AWS_SECRET_ACCESS_KEY" do
    ENV['AWS_SECRET_ACCESS_KEY'] = 'SACCESS7'
    ENV['AWS_SECRET_KEY'] = 'SECRET33' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.secretkey
  end
  drill "reads AWS_SECRET_ACCESS_KEY" do
    ENV['AWS_SECRET_ACCESS_KEY'] = 'SACCESS7'
    ENV['AWS_SECRET_KEY'] = nil or Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.secretkey
  end
  drill "reads EC2_CERT" do
    ENV['EC2_CERT'] = 'CERT22' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.cert
  end
  drill "reads EC2_PRIVATE_KEY" do
    ENV['EC2_PRIVATE_KEY'] = 'PK100' and Rudy::Huxtable.reset_global
    Rudy::Huxtable.global.pkey
  end
  drill "reads EC2_PRIVATE_KEY" do
    ENV['USER'] = 'PK100'
    Rudy::Huxtable.global.pkey
  end
end
dreams "Global knows ENV" do
  dream "reads AWS_ACCESS_KEY", 'ACCESS99'
  dream "reads AWS_SECRET_KEY before AWS_SECRET_ACCESS_KEY", 'SECRET33'
  dream "reads AWS_SECRET_ACCESS_KEY", 'SACCESS7'
  dream "reads EC2_CERT", File.expand_path('CERT22')
  dream "reads EC2_PRIVATE_KEY", File.expand_path('PK100')
end


tryout "Population of Global" do
  setup do
    Rudy::Huxtable.update_config
  end
end
dreams "Population of Global" do
  dream "has default region", :'us-east-1'
  dream "has default user", :rudy
end