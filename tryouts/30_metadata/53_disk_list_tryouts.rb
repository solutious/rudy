
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "List Disks" do
  
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
    Rudy::Disk.new('/any/path1').save :replace
    Rudy::Disk.new('/any/path2').save :replace
    sleep 1
  end
  
  clean do
    Rudy::Disk.new('/any/path1').destroy
    Rudy::Disk.new('/any/path2').destroy
  end
  
  dream :class, Array
  dream :empty?, false
  drill "can list available disks" do
    Rudy::Disks.list
  end
  
  
end



