
module Rudy; module Routines; module Handlers;
  module User
    include Rudy::Routines::Handlers::Base
    extend self 
    
    Rudy::Routines.add_handler :adduser, self
    Rudy::Routines.add_handler :authorize, self
    
    def raise_early_exceptions(type, user, rset, lbox, argv=nil)
      
    end
    
    def execute(type, user, rset, lbox, argv=nil)
      raise NoMachines if rset.boxes.empty?
      send(type, user, rset)
    end
    
    def adduser(user, robj)
      
      # On Solaris, the user's home directory needs to be specified
      # explicitly so we do it for linux too for fun. 
      homedir = robj.guess_user_home(user.to_s)
      
      # When more than one machine is running, this will be an Array
      homedir = homedir.first if homedir.kind_of?(Array)
      
      args = [:m, :d, homedir, :s, '/bin/bash', user.to_s]
      
      # NOTE: We'll may to use platform specific code here. 
      # Linux has adduser and useradd commands:
      # adduser can prompt for info which we don't want. 
      # useradd does not prompt (on Debian/Ubuntu at least). 
      # We need to specify bash b/c the default is /bin/sh
      
      if robj.user.to_s == 'root'
        robj.useradd args
      else
        robj.sudo do
          useradd args
        end
      end
      
    end
    
    def authorize(user, robj)
      robj.authorize_keys_remote(user.to_s)
    end
    
    
  end
  
end; end; end