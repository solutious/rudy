
group "Metadata"
library :rudy, 'lib'

Gibbler.enable_debug if Tryouts.verbose > 3
  
tryout "List Machines" do
  
  setup do
    Rudy.enable_debug
    Rudy::Huxtable.update_config          # Read config files
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    Rudy::Metadata.connect akey, skey, region
    ('01'..'03').each { |i| Rudy::Machine.new(i).save }
    ('04'..'05').each { |i| Rudy::Machine.new(i, :environment => :test).save }
    sleep 1 # SimpleDB, eventual consistency
  end
  
  clean do
    ('01'..'03').each { |i| Rudy::Machine.new(i).destroy }
    ('04'..'05').each { |i| Rudy::Machine.new(i, :environment => :test).destroy }
    if Rudy.debug?
      puts $/, "Rudy Debugging:"
      Rudy::Huxtable.logger.rewind
      puts Rudy::Huxtable.logger.read
    end
  end
  
    
  dream :class, Array
  dream :empty?, false
  dream :size, 3
  drill "list available disks in default environment" do
    ret = Rudy::Machine.list
    #puts ret.to_json
    ret
  end
  
  dream :size, 2
  drill "list available disks in 'test' environment" do
    ret = Rudy::Machine.list({:environment => :test})
    #puts ret.to_json
    ret
  end
  
  dream :size, 5
  drill "list all available disks" do
    ret = Rudy::Machine.list({}, [:environment])
    #puts ret.to_json
    ret
  end
  
end



