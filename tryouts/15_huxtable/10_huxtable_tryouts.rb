

group "Rudy::Huxtable"
library :rudy, 'lib'

tryout "Is well kept" do
  set :oldlogger, Rudy::Huxtable.logger
  setup do
    #Rudy::Huxtable.update_config
  end
  clean do
    Rudy::Huxtable.update_logger oldlogger
  end
  
  drill "has config", Rudy::Huxtable.config, :class, Rudy::Config
  drill "has global", Rudy::Huxtable.global, :class, Rudy::Global 
  drill "has logger", Rudy::Huxtable.logger, :class, StringIO
  drill "specify logger", :class, IO do
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
