
group "Metadata"
library :rudy, 'lib'
tryouts "include Rudy::Metadata" do
  set :test_domain, 'test_' #<< Rudy::Utils.strand
  
  setup do
    Rudy::Huxtable.global.offline = true
    Rudy::Huxtable.update_config          # Read config files
  end
  clean do
    Rudy::Huxtable.global.offline = false
  end
  
  drill "has default domain", Rudy::DOMAIN do
    Rudy::Metadata.domain
  end
  
  drill "can set domain", test_domain do
    Rudy::Metadata.domain = test_domain
  end
  
  drill "can open simpledb connection", true do
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
  end
  
  dream test_domain
  drill "can create test domain (automatically sets new internal domain)" do
    Rudy::Metadata.domain = Rudy::DOMAIN
    Rudy::Metadata.create_domain test_domain
  end
  
  dream [:environment, :region, :role, :rtype, :zone]
  drill "can build a default criteria" do
    Rudy::Metadata.build_criteria(Rudy::Machines::RTYPE).keys.sort
  end
  
  dream true
  drill "can destroy domain (automatically returns to default)" do
    Rudy::Metadata.destroy_domain test_domain
  end
  
end
