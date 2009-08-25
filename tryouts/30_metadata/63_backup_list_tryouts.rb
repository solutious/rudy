
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "List Backups" do
  
  set :sample_time, Time.now.utc
  
  setup do
    #Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    Rudy::AWS::EC2.connect akey, skey, region
    Rudy::Backup.new(1, '/any/path1', :created => sample_time).save :replace
    Rudy::Backup.new(2, '/any/path2', :created => sample_time).save :replace
  end
  
  clean do
    Rudy::Backup.new(1, '/any/path1', :created => sample_time).destroy
    Rudy::Backup.new(2, '/any/path2', :created => sample_time).destroy
  end
  
  dream :class, Array
  dream :empty?, false
  dream :size, 2
  drill "can list available backups" do
    Rudy::Backups.list
  end
  
  
end



