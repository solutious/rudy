
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Accounts" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "has aws account" do
    # Sorted so we can add new keys without breaking the test
    @@config.accounts.aws.keys.collect { |v| v.to_s }.sort
  end
  
end
dreams "Accounts" do
  dream "has aws account" do 
    output ["accesskey", "accountnum", "cert", "name", "privatekey", "secretkey"]
  end
  
end