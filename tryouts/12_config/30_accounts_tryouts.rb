
group "Config"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Accounts" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  dream ["accesskey", "accountnum", "cert", "name", "pkey", "secretkey"]
  drill "has aws account" do
    # Sorted so we can add new keys without breaking the test
    @@config.accounts.aws.keys.collect { |v| v.to_s }.sort
  end
  
end
