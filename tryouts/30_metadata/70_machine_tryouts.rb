
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Metadata"

test_domain = 'test_' #<< Rudy::Utils.strand
test_env = 'env_' << Rudy::Utils.strand

tryout "Rudy::Machine instance API" do

  drill "create new machine instance", Rudy::Machine, :class do
    Rudy::Machine.new
  end
  
  
end

tryout "Rudy::Machine class API" do
  
  dream /reg/, :match
  dream /c.ntent/, :match
  drill "data" do
    Rudy::Machine.data
  end
  
  dream 0, :size
  dream Array, :class
  drill "can list" do
    Rudy::Machine.list
  end
  
  dream 0, :size
  dream Hash, :class
  drill "can list as hash" do
    Rudy::Machine.list_as_hash
  end
  
  dream Rudy::Machine, :class
  drill "can get a machine" do
    Rudy::Machine.get
  end
  
  dream Rudy::Machine, :class
  drill "can find a machine" do
    Rudy::Machine.find
  end
  
  
  
end