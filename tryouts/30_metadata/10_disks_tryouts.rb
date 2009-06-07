rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

tryout "Disk API" do
  setup do
    Rudy::Huxtable.update_config
    @@disk = Rudy::MetaData::Disk.new
  end
  
  drill "has disk instance" do
    @@disk
  end
  
  drill "create disk" do
    @@disk
  end
  
end


tryout "Disk API" do
  dream "has disk instance", Rudy::MetaData::Disk, :class
  dream "create disk", ''
end