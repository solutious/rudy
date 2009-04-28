
module Rudy; module Routines; 
  module UserHelper
    include Rudy::Routines::HelperBase  # TODO: use execute_rbox_command
    extend self 
    
    def adduser?(routine)
      (!routine.adduser.nil? && !routine.adduser.empty?)
    end
    def adduser(routine, machine, rbox)
      args = [:m, :s, '/bin/bash', routine.adduser.to_s]
      puts command_separator(rbox.preview_command(:useradd, args), routine.adduser.to_s)
      
      # NOTE: We'll may to use platform specific code here. 
      # Linux has adduser and useradd commands:
      # adduser can prompt for info which we don't want. 
      # useradd does not prompt (on Debian/Ubuntu at least). 
      # We need to specify bash b/c the default is /bin/sh
      execute_rbox_command { rbox.useradd(args) }
    end
    
    def authorize?(routine)
      (!routine.authorize.nil? && !routine.authorize.empty?)
    end
    def authorize(routine, machine, rbox)
      puts command_separator(:authorize_keys_remote, routine.authorize)
      execute_rbox_command { rbox.authorize_keys_remote(routine.authorize) }
    end
    
    
  end
  
end; end  