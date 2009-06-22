require 'tempfile'

module Rudy; module Routines; 
  #--
  # TODO: Rename to ShellHelper
  #++
  module ScriptHelper
    include Rudy::Routines::HelperBase 
    extend self
    
    Rudy::Routines.add_helper :local,  self
    Rudy::Routines.add_helper :remote, self
    
    def raise_early_exceptions(type, batch, rset, lbox, argv=nil)
      
    end
    
    def execute(type, batch, rset, lbox, argv=nil)
      # It's important this stay a regex rather than a literal comparison
      if type.to_s =~ /local/   
        lbox.cd Dir.pwd
        batch = { lbox.user => batch } if batch.is_a?(Proc)
        execute_command(batch, lbox, argv)
      else
        batch = { rset.user => batch } if batch.is_a?(Proc)
        execute_command(batch, rset, argv)
      end
    end

    
  private  

    # * +batch+ a single routine hash (startup, shutdown, etc...)
    # * +robj+ an instance of Rye::Set or Rye::Box 
    # * +argv+ command line args
    def execute_command(batch, robj, argv=nil)
      
      # We need to explicitly add the rm command for rbox so we
      # can delete the script config file when we're done. This
      # adds the method to this instance of rbox only.
      # We give it a funny so we can delete it knowing we're not
      # deleting a method added somewhere else. 
      def robj.rudy_tmp_rm(*args); cmd('rm', args); end
      
      original_user = robj.user
      
      batch.each_pair do |user, proc|
        unless File.exists?(user_keypairpath(user) || '')
          le "Cannot find key for #{user}: #{user_keypairpath(user)}"
        end
        
        if user.to_s != robj.user
          begin
            ld "Switching user to: #{user} (was: #{robj.user})"
            
            robj.add_key user_keypairpath(user)
            robj.switch_user user
            robj.connect
          rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
            STDERR.puts "Error connecting: #{ex.message}".color(:red)
            STDERR.puts "Skipping user #{user}".color(:red)
            next
          end
        end
        
        ### EXECUTE THE COMMANDS BLOCK
        begin
          robj.batch(argv, &proc)
        ensure
          robj.enable_safe_mode          # In case it was disabled
          robj.switch_user original_user # Return to the user it was provided with
        end
        
        robj.cd # reset to home dir
      end
      
      
      
      
    end
  end
  
end;end