
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "Disk API" do
  
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
  end
  
  dream :class, Gibbler::Digest
  drill "has gibbler digest" do
    Rudy::Disk.new('/any/path').gibbler
  end
  
  
end
