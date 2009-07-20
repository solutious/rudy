
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Metadata"

test_domain = 'test_' #<< Rudy::Utils.strand
test_env = 'env_' << Rudy::Utils.strand

xtryout "Rudy::Machine instance API" do

  dream :class, Rudy::Machine
  drill "create new machine instance" do
    Rudy::Machine.new
  end
  
  
end

xtryout "Rudy::Machine class API" do
  
  dream :match, /reg/
  dream :match, /c.ntent/
  drill "data" do
    Rudy::Machine.data
  end
  
  dream :size, 0
  dream :class, Array
  drill "can list" do
    Rudy::Machine.list
  end
  
  dream :size, 0
  dream :class, Hash
  drill "can list as hash" do
    Rudy::Machine.list_as_hash
  end
  
  dream :class, Rudy::Machine
  drill "can get a machine" do
    Rudy::Machine.get
  end
  
  dream :class, Rudy::Machine
  drill "can find a machine" do
    Rudy::Machine.find
  end
  
  
  
end