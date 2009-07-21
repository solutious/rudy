
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "List Disks" do
  
  setup do
    Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
  end
  
  dream [:environment, :region, :role, :zone]
  drill "can build a default criteria" do
    Rudy::Metadata.build_criteria.keys.sort
  end
  
  dream :class, Array
  dream :empty?, false
  drill "can list available disks" do
    Rudy::Disk.list
  end
  
  
end



