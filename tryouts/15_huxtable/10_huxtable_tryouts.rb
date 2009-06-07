
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Rudy::Huxtable"
library :rudy, rudy_lib_path

tryout "Is well kept" do
  setup do
    #Rudy::Huxtable.update_config
  end

  drill "has config", Rudy::Huxtable.config  
  drill "has global", Rudy::Huxtable.global  
  drill "has logger", Rudy::Huxtable.logger
  drill "specify logger" do
    Rudy::Huxtable.update_logger STDOUT
    Rudy::Huxtable.logger
  end
  
 # drill "knows where config lives", Rudy::Huxtable.config_dirname 
end
dreams "Is well kept" do
  dream "has config", Rudy::Config, :class
  dream "has global", Rudy::Global, :class
  dream "has logger", StringIO, :class
  dream "specify logger", IO, :class
end

tryout "Loads configuration" do
  
end


tryout "Knows the defaults" do
  setup do
    class ::Olivia                 # :: to define the class in the root context
      include Rudy::Huxtable
    end
  end
  
  drill "create olivia" do
    @@olivia = Olivia.new
    @@olivia.class.to_s
  end
  
  drill "machine group" do
    @@olivia.current_machine_group
  end
  
end
dreams "Knows the defaults" do
  dream "create olivia", 'Olivia'
  dream "machine group", 'stage-app'
end