
rudy_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Loads config files" do
  
  drill "load configs when created" do
    @@config = Rudy::Config.new Rudy::CONFIG_FILE
    @@config.paths.size
  end
  
  drill "has accounts" do
    @@config.accounts
  end
  drill "has defaults" do
    @@config.defaults
  end
  
  drill "loads additional configs" do
    @@config.paths << File.join(RUDY_HOME, 'Rudyfile')
    @@config.refresh
    @@config.paths.size
  end
  
  drill "has machines" do
    @@config.machines
  end
  drill "has commands" do
    @@config.commands
  end
  drill "has routines" do
    @@config.routines
  end
  
  drill "autoloads known configs" do
    conf = Rudy::Config.new
    conf.look_and_load   # Needs to run before checking accounts, et al
    (!conf.paths.empty? && !conf.paths.nil?)
  end
  
end
dreams "Loads config files" do
  dream "load configs when created", 1
  dream "has accounts", Rudy::Config::Accounts, :class
  dream "has defaults", Rudy::Config::Defaults, :class
  dream "loads additional configs", 2
  dream "has machines", Rudy::Config::Machines, :class
  dream "has commands", Rudy::Config::Commands, :class
  dream "has routines", Rudy::Config::Routines, :class
  dream "autoloads known configs", true
end


