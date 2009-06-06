
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Rudy MetaData"
library :rudy, rudy_lib_path

tryout "Disk API" do
  setup do
    Rudy::Huxtable.update_config
  end
  
  drill "create disk" do
    disk = Rudy::MetaData::Disk.new
  end
  
end


tryout "Disk API" do
  dream "create disk", Rudy::MetaData::Disk, :class
end