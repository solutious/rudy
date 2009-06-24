
group "Config"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Loads config files" do
  
  drill "load configs when created", 1 do
    @@config = Rudy::Config.new Rudy::CONFIG_FILE
    @@config.paths.size
  end
  
  drill "has accounts", Rudy::Config::Accounts, :class do
    @@config.accounts
  end
  drill "has defaults", Rudy::Config::Defaults, :class do
    @@config.defaults
  end
  
  drill "loads additional configs", 2 do
    @@config.paths << File.join(RUDY_HOME, 'Rudyfile')
    @@config.refresh
    @@config.paths.size
  end
  
  drill "has machines", Rudy::Config::Machines, :class do
    @@config.machines
  end
  drill "has commands", Rudy::Config::Commands, :class do
    @@config.commands
  end
  drill "has routines", Rudy::Config::Routines, :class do
    @@config.routines
  end
  
  drill "autoloads known configs", true do
    conf = Rudy::Config.new
    conf.look_and_load   # Needs to run before checking accounts, et al
    (!conf.paths.empty? && !conf.paths.nil?)
  end
  
end


