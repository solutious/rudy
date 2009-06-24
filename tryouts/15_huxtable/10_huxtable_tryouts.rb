
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Rudy::Huxtable"
library :rudy, rudy_lib_path

tryout "Is well kept" do
  setup do
    #Rudy::Huxtable.update_config
  end

  drill "has config", Rudy::Huxtable.config, Rudy::Config, :class
  drill "has global", Rudy::Huxtable.global, Rudy::Global, :class 
  drill "has logger", Rudy::Huxtable.logger, StringIO, :class
  drill "specify logger", IO, :class do
    Rudy::Huxtable.update_logger STDOUT
    Rudy::Huxtable.logger
  end
  
 # drill "knows where config lives", Rudy::Huxtable.config_dirname 
end

tryout "Loads configuration" do
  
end


tryout "Knows the defaults" do
  setup do
    class ::Olivia                 # :: to define the class in the root context
      include Rudy::Huxtable
    end
  end
  
  drill "create olivia", 'Olivia' do
    @@olivia = Olivia.new
    @@olivia.class.to_s
  end
  
  drill "machine group", 'stage-app' do
    @@olivia.current_machine_group
  end
  
end
