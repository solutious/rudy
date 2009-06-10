
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Machines" do
  drill "Setup vars" do
    dream true
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
    @@reg, @@zon = @@config.defaults.region, @@config.defaults.zone 
    @@env, @@rol = @@config.defaults.environment, @@config.defaults.role
    true
  end
  
  drill "example stage is defined" do
    @@config.machines.stage
  end
  drill "has example AMIs by zone" do
    [@@config.machines[:'us-east-1b'].ami, @@config.machines[:'eu-west-1b'].ami]
  end
  
  drill "can find us-east-1 AMI" do
    @@config.machines.find(:"us-east-1b", :ami)
  end
  drill "can find eu-west-1 AMI" do
    @@config.machines.find(:"eu-west-1b", :ami)
  end
  drill "different default AMI for each zone" do
    eu = @@config.machines.find(:"eu-west-1b", :ami)
    us = @@config.machines.find(:"us-east-1b", :ami)
    eu != us
  end
  drill "conf hash and find are equal" do
    conf = @@config.machines[@@env][@@rol]
    find = @@config.machines.find(@@env, @@rol)
    conf == find
  end
  drill "conf find and find_deferred are equal" do
    find = @@config.machines.find(@@env, @@rol)
    find_def = @@config.machines.find_deferred(@@env, @@rol)
    find == find_def
  end
end
dreams "Machines" do
  dream "example stage is defined", {
      :size=>"m1.small", 
      :app=>{:positions=>1, :disks=>{"/rudy/disk1"=>{:size=>2, :device=>"/dev/sdr"}}}, 
      :db=>{}, :balancer=>{}, :users=>{:rudy=>{:keypair=>"/path/2/private-key"}}
  }
  dream "has example AMIs by zone", ["ami-e348af8a", "ami-6ecde51a"]
  
  dream "can find us-east-1 AMI", 'ami-e348af8a'
  dream "can find eu-west-1 AMI", 'ami-6ecde51a'
  dream "different default AMI for each zone", true
  dream "conf hash and find are equal", true
  dream "conf find and find_deferred are equal", true
end

