
module Rudy; module Routines; 
  
  module ScriptHelper
    extend self
    
    def before_local(routine, rbox)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
    end
    def before(routine, rbox)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
    end


    def after(routine, machine, rbox)
      raise "Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      
      original_user = rbox.user
      
      puts "On #{machine.name}"
      (routine.after || []).each do |after|
        user, command, *args = after.to_a.flatten.compact
        rbox.switch_user user # does nothing if it's the same user
        puts "Running #{rbox.preview_command(command, args)} (#{user})"
        puts rbox.send(command, args)
      end
      
      rbox.switch_user original_user
    end
    
    def after_local(routine, machine, rbox)
      raise "Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      raise "Not a Rye::Box" unless rbox.is_a?(Rye::Box)
    end
  


  
  private  
    
  
  end
  
end;end