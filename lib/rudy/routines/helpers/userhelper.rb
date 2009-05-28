
module Rudy; module Routines; 
  module UserHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self 
    
    def adduser?(routine)
      (!routine.adduser.nil? && !routine.adduser.to_s.empty?)
    end
    def adduser(routine, machine, rbox)
      
      # On Solaris, the user's home directory needs to be specified
      # explicitly so we do it for linux too for fun. 
      homedir = rbox.guess_user_home(routine.adduser.to_s)
      args = [:m, :d, homedir, :s, '/bin/bash', routine.adduser.to_s]
      puts command_separator(rbox.preview_command(:useradd, args), rbox.user)
      
      # NOTE: We'll may to use platform specific code here. 
      # Linux has adduser and useradd commands:
      # adduser can prompt for info which we don't want. 
      # useradd does not prompt (on Debian/Ubuntu at least). 
      # We need to specify bash b/c the default is /bin/sh
      trap_rbox_errors { rbox.useradd(args) }
    end
    
    def authorize?(routine)
      (!routine.authorize.nil? && !routine.authorize.to_s.empty?)
    end
    def authorize(routine, machine, rbox)
      puts command_separator(:authorize_keys_remote, rbox.user)
      trap_rbox_errors { rbox.authorize_keys_remote(routine.authorize) }
    end
    
    
  end
  
end; end  