
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Defaults" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "has some defaults" do
    # Sorted so we can add new keys without breaking the test
    @@config.defaults.keys.collect { |v| v.to_s }.sort
  end
  
end
dreams "Defaults" do
  dream "has some defaults" do 
    output ["environment", "role", "zone"].sort
  end
  
end