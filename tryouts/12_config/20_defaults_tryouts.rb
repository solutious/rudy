
rudy_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Defaults" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "has all defaults" do
    # Sorted so we can add new keys without breaking the test
    @@config.defaults.keys.collect { |v| v.to_s }.sort
  end
  
end
dreams "Defaults" do
  dream "has all defaults" do 
    output ["color", "environment", "region", "role", "user", "yes", "zone"].sort
  end
  
end