
rudy_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Routines" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "has aws account" do
  end
  
end
dreams "Routines" do
  dream "has aws account" do 
  end
  
end