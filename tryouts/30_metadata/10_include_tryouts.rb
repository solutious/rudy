test_domain = 'test_' #<< Rudy::Utils.strand

group "Metadata"
library :rudy, 'lib'
tryouts "include Rudy::Metadata" do
  
  setup do
    Rudy::Huxtable.global.offline = true
    Rudy::Huxtable.update_config          # Read config files
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
  
  drill "can create test domain (automatically sets new internal domain)", test_domain do
    Rudy::Metadata.domain = Rudy::DOMAIN
    Rudy::Metadata.create_domain test_domain
  end
  
  drill "can destroy domain (automatically returns to default)", Rudy::DOMAIN do
    Rudy::Metadata.destroy_domain test_domain
  end
  
end
