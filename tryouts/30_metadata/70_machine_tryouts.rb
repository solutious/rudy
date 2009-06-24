
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
  
  drill "can list", Array, :class do
    Rudy::Machine.list
  end
  
end