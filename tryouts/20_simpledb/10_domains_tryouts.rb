rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "SimpleDB"

test_domain = 'test_' << Rudy::Utils.strand
sdb = nil

tryouts "Domains" do
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  drill "create simpledb connection", :class, Rudy::AWS::SDB do
    sdb
  end
  
  drill "create a domain (#{test_domain})", true do
    sdb.create_domain test_domain
  end
  
  drill "list domains", :class, Array do
    stash :domains, sdb.list_domains
  end
  
  drill "destroy a domain (#{test_domain})", true do
    sdb.destroy_domain test_domain
  end
  
end




