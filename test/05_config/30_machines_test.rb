
module Rudy::Test
  class Config
    
    context "(30) #{name} Machines" do
      should "(00) have config" do
        #Caesars.enable_debug
        reg, zon = @@global.region, @@global.zone
        env, rol = @@global.environment, @@global.role
        puts "%s %s %s %s" % [reg, zon, env, rol]
        
        p @@config.machines.find_deferred([reg, zon], env, rol)
        p @@config.machines.find_deferred(reg, env, rol)
        p @@config.machines[reg][env]#[rol]
        p @@config.machines.find(reg, env, rol)
      end
    end
    
  end
end