rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "SimpleDB"

name_of_domain = Rudy::Utils.strand

tryouts "Domains" do
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @@sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  drill "create simpledb connection" do
    @@sdb
  end
  
  drill "create a domain (#{name_of_domain})" do
    @@sdb.create_domain name_of_domain
  end
  
  drill "list domains" do
    stash :domains, @@sdb.list_domains
  end
  
  drill "destroy a domain (#{name_of_domain})" do
    @@sdb.destroy_domain name_of_domain
  end
  
end
dreams "Domains" do
  dream "create simpledb connection", Rudy::AWS::SDB, :class
  dream "create a domain (#{name_of_domain})", true
  dream "list domains", Array, :class
  dream "destroy a domain (#{name_of_domain})", true
end




