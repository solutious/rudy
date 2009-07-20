
library :rudy, 'lib'

group "SimpleDB"

tryouts "Domains" do
  set :test_domain, 'test_' << Rudy::Utils.strand

  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  drill "create simpledb connection", :class, Rudy::AWS::SDB do
    @sdb
  end
  
  drill "create a domain (#{test_domain})", true do
    @sdb.create_domain test_domain
  end
  
  drill "list domains", :class, Array do
    stash :domains, @sdb.list_domains
  end
  
  drill "destroy a domain (#{test_domain})", true do
    @sdb.destroy_domain test_domain
  end
  
end




