
LIB_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

group "Rudy Disks"
library :rudy, LIB_DIR

tryout "rudy machines", :api do
  setup do
  end
  
  drill "no machines, no args" 
end
