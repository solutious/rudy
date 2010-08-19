

module Rudy; module Routines; module Handlers;
  module Script
    include Rudy::Routines::Handlers::Base 
    extend self
    
    Rudy::Routines.add_handler :local,  self
    Rudy::Routines.add_handler :remote, self
    
    Rudy::Routines.add_handler :xlocal,  self
    Rudy::Routines.add_handler :xremote, self
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def execute(type, batch, rset, lbox, argv=nil)
      if type.to_s =~ /\Ax/     # (e.g. xremote, xlocal)
        # do nothing 
        
      # It's important this stay a regex rather than a literal comparison
      elsif type.to_s =~ /local/   
        lbox.cd Dir.pwd
        batch = { lbox.user => batch } if batch.is_a?(Proc)
        execute_command(batch, lbox, argv)
      else
        batch = { rset.user => batch } if batch.is_a?(Proc)
        raise NoMachines if rset.boxes.empty?
        execute_command(batch, rset, argv)
      end
    end

    
  private  

    # * +batch+ a single routine hash (startup, shutdown, etc...)
    # * +robj+ an instance of Rye::Set or Rye::Box 
    # * +argv+ command line args
    def execute_command(batch, robj, argv=nil)
      
      original_user = robj.user
      original_dir = robj.current_working_directory

      batch.each_pair do |user, proc|
        
        # The error doesn't apply to the local Rye::Box instance
        if robj.is_a?(Rye::Set) && !File.exists?(user_keypairpath(user) || '')
          # TODO: This prints always even if an account is authorized with different keys. 
          #le "Cannot find key for #{user}: #{user_keypairpath(user)}"          
        end
        
        if user.to_s != robj.user
          begin
            ld "Switching user to: #{user} (was: #{robj.user})"
            ld "(key: #{user_keypairpath(user)})"
            
            robj.add_key user_keypairpath(user)
            robj.switch_user user
            
          rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
            le "Error connecting: #{ex.message}".color(:red)
            le "Skipping user #{user}".color(:red)
            next
          end
        end
        
        ### EXECUTE THE COMMANDS BLOCK
        begin
          robj.batch(argv, &proc)
        rescue Rye::Err => ex
          # No need to bubble exception up when in parallel mode
          raise ex unless Rye::Set == robj
        ensure
          robj.enable_safe_mode            # In case it was disabled
          robj.switch_user original_user   # Return to the user it was provided with          
          robj.cd                          # reset to home dir
          robj.cd original_dir             # return to previous directory
        end
        
      end
      
      
    end
  end
  
end;end;end