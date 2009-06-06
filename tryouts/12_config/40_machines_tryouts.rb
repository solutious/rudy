
rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

group "Config"
library :rudy, rudy_lib_path

tryout "Machines" do
  setup do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
  end
  
  drill "example stage is defined" do
    @@config.machines.stage
  end
  
  drill "has example AMIs by zone" do
    [@@config.machines[:'us-east-1b'].ami, @@config.machines[:'eu-west-1b'].ami]
  end
  
end
dreams "Machines" do
  dream "example stage is defined", {
      :size=>"m1.small", 
      :app=>{:positions=>1, :disks=>{"/rudy/disk1"=>{:size=>2, :device=>"/dev/sdr"}}}, 
      :db=>{}, :balancer=>{}, :users=>{:rudy=>{:keypair=>"/path/2/private-key"}}
  }
  dream "has example AMIs by zone", ["ami-e348af8a", "ami-6ecde51a"]
end