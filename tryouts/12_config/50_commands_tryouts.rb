
LIB_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

group "Config"
library :rudy, LIB_DIR

tryout "Commands" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "is a well-formed hash" do
    @@config.commands.to_hash.keys.uniq.sort
  end
  
end
dreams "Commands" do
  dream "is a well-formed hash", [:allow], :poop
end