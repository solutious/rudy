
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Commands" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "is a well-formed hash", [:allow] do
    @@config.commands.to_hash.keys.uniq.sort
  end
  
end
