
group "Require-time"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Rudy Initialization" do
  setup do
  end

  drill "version matches gemspec", Rudy::VERSION.to_s do
    require 'rubygems' unless defined?(Gem)
    eval( File.read(File.join(RUDY_HOME, 'rudy.gemspec')))
    @spec.version.to_s
  end
  
  drill             "has sysinfo", Rudy.sysinfo, :class, SysInfo
  drill       "debug is disabled", Rudy.debug?, false
  drill       "quiet is disabled", Rudy.quiet?, false
  drill    "auto-yes is disabled", Rudy.auto?, false
  
  drill "debug can be enabled", true do
    #Rudy.enable_debug
    Rudy.debug?
  end
  
  drill "debug can be disabled", false do
    Rudy.disable_debug
    Rudy.debug?
  end
  
end



