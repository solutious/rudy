rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "SimpleDB"

test_domain = 'test_' << Rudy::Utils.strand

tryouts "Domains" do
  drill "Has stuff" do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @@ec2 = Rudy::AWS::SDB.new(akey, skey, region)
    true
  end
  
  drill "has ec2 instance" do
    @@ec2
  end
  
end
dreams "Domains" do
  dream "create simpledb connection", Rudy::AWS::SDB, :class
  dream "create a domain (#{test_domain})", true
  dream "list domains", Array, :class
  dream "destroy a domain (#{test_domain})", true
end
