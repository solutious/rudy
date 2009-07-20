
test_domain = 'test_' #<< Rudy::Utils.strand

group "Metadata"
library :rudy, 'lib'
tryouts "include Rudy::Metadata" do
  
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
  end
  
  drill "can include Rudy::Metadata", 'Anything' do
    class ::Anything < Storable
      include Rudy::Metadata
      def rvol; @@rvol; end
    end
    Anything.name.to_s
  end
  
  dream [:region, :zone, :environment, :role, :position]
  drill "sets up common fields on include" do
    Anything.field_names
  end
  
  dream :class, Rudy::AWS::EC2::Volumes
  drill "creates instance of Rudy::AWS::EC2::Volumes" do
    Anything.new('anything').rvol
  end
  
end