


group "Metadata"
library :rudy, 'lib'
tryouts "Rudy::Metadata objects" do
  set :test_domain, 'test_' #<< Rudy::Utils.strand
  
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    class Anything < Storable
      include Rudy::Metadata
    end
  end

  dream [:region, :zone, :environment, :role, :position]
  drill "sets up common fields on include" do
    Anything.field_names
  end
  
end