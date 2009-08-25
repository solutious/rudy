
group "Config"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Defaults" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "has some defaults", ["color", "environment", "role", "zone"].sort do
    # Sorted so we can add new keys without breaking the test
    @@config.defaults.keys.collect { |v| v.to_s }.sort
  end
  
end
