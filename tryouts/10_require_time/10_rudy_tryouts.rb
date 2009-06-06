
rudy_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

group "Require-time"
library :rudy, rudy_lib_path

tryout "Rudy Initialization" do
  setup do
  end

  drill "version matches gemspec", Rudy::VERSION.to_s
  drill             "has sysinfo", Rudy.sysinfo
  drill       "debug is disabled", Rudy.debug?
  drill       "quiet is disabled", Rudy.quiet?
  drill    "auto-yes is disabled", Rudy.yes?
  
  drill "debug can be enabled" do
    Rudy.enable_debug
    Rudy.debug?
  end
  
  drill "debug can be disabled" do
    Rudy.disable_debug
    Rudy.debug?
  end
  
end

dreams "Rudy Initialization" do
  
  dream "version matches gemspec" do
    require 'rubygems' unless defined?(Gem)
    eval( File.read(File.join(RUDY_HOME, 'rudy.gemspec')))
    output @spec.version.to_s
  end
  
  dream           "has sysinfo", SysInfo, :class
  dream     "debug is disabled", false
  dream     "quiet is disabled", false
  dream  "auto-yes is disabled", false
  
  dream  "debug can be enabled", true
  dream "debug can be disabled", true
  
end


