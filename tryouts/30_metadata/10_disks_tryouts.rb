
rudy_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

group "Rudy MetaData"
library :rudy, rudy_lib_path

tryout "Disk API" do
  setup do
     
  end
  
  
  drill "create disk" do
    disk = Rudy::MetaData::Disk.new
  end
  
end


tryout "Disk API" do
  dream "create disk", String, :class
end