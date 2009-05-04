require 'tempfile'

module Rudy; module Routines; 
  #--
  # TODO: Rename to ShellHelper
  #++
  module ScriptHelper
    include Rudy::Routines::HelperBase  # TODO: use execute_rbox_command
    extend self

    @@script_types = [:after, :before, :after_local, :before_local, :script]
    @@script_config_file = "rudy-config.yml"
    
    def before_local(routine, sconf, rbox)
      execute_command(:before_local, routine, sconf, 'localhost', rbox)
    end
    def before_local?(routine)
      # before_local generally doesn't take a user name like the remote
      # before block so we add it here (unless the user did specify it)
      routine[:before_local] = { 
        Rudy.sysinfo.user.to_sym => routine.delete(:before_local) 
      } if routine[:before_local].is_a?(Proc)
      
      execute_command?(:before_local, routine)
    end
      
    def after_local(routine, sconf, rbox)
      execute_command(:after_local, routine, sconf, 'localhost', rbox)
    end
    def after_local?(routine)
      routine[:after_local] = {                 # See before_local note
        Rudy.sysinfo.user.to_sym => routine.delete(:after_local) 
      } if routine[:after_local].is_a?(Proc)
      execute_command?(:after_local, routine)
    end
    
    def before(routine, sconf, machine, rbox)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:before, routine, sconf, machine.name, rbox)
    end
    def before?(routine); execute_command?(:before, routine); end
    
    def after(routine, sconf, machine, rbox)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:after, routine, sconf, machine.name, rbox)
    end
    def after?(routine); execute_command?(:after, routine); end
    
    def script(routine, sconf, machine, rbox)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:script, routine, sconf, machine.name, rbox)
    end
    def script?(routine); execute_command?(:script, routine); end

  
  private  
    
    # Does the routine have the requested script type?
    # * +timing+ is one of: after, before, after_local, before_local
    # * +routine+ a single routine hash (startup, shutdown, etc...)
    # Prints notice to STDERR if there's an empty conf hash
    def execute_command?(timing, routine)
      hasconf = (routine.is_a?(Caesars::Hash) && routine.has_key?(timing))
      return false unless hasconf
      routine[timing].each_pair do |user,proc|
        #p [timing, user, proc].join(', ')
        if proc.nil? || !proc.is_a?(Proc)
          STDERR.puts "Empty #{timing} config for #{user}"
        else
          return true
        end
      end
      false
    end
    
    # * +timing+ is one of: after, before, after_local, before_local
    # * +routine+ a single routine hash (startup, shutdown, etc...)
    # * +sconf+ is a config hash from machines config (ignored if nil)
    # * +hostname+ machine hostname that we're working on
    # * +rbox+ a Rye::Box instance for the machine we're working on
    def execute_command(timing, routine, sconf, hostname, rbox)
      raise "ScriptHelper: Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      raise "ScriptHelper: #{timing}?" unless @@script_types.member?(timing)
      
      if sconf && !sconf.empty?
        tf = Tempfile.new(@@script_config_file)
        Rudy::Utils.write_to_file(tf.path, sconf.to_hash.to_yaml, 'w')
      end
      
      if execute_command?(timing, routine) # i.e. before_local?

        # We need to explicitly add the rm command for rbox so we
        # can delete the script config file when we're done. This
        # adds the method to this instance of rbox only.
        # We give it a funny so we can delete it knowing we're not
        # deleting a method added somewhere else. 
        def rbox.rudy_tmp_rm(*args); cmd('rm', args); end
        
        original_user = rbox.user
        user_blocks = routine[timing] || {}
        users = user_blocks.keys
        # Root stuff is always run first. 
        users.unshift(users.delete(:root)) if users.member?(:root)
        users.each do |user|
          proc = user_blocks[user]
          
          begin
            rbox.switch_user user # does nothing if it's the same user
            rbox.connect(false)   # does nothing if already connected
          rescue Net::SSH::AuthenticationFailed, Net::SSH::HostKeyMismatch => ex  
            STDERR.puts "Error connecting: #{ex.message}".color(:red)
            STDERR.puts "Skipping user #{user}".color(:red)
            next
          end
          
          execute_rbox_command {
            # We need to create the config file for every script, 
            # b/c the user may change and it would not be accessible.
            # We turn off safe mode so we can write the config file via SSH. 
            # This will need to use SCP eventually; it is unsafe and error prone.
            # TODO: Replace with rbox.upload. Make it safe again!
            conf_str = StringIO.new
            conf_str.puts sconf.to_hash.to_yaml
            rbox.upload(conf_str, @@script_config_file)
            rbox.chmod(600, @@script_config_file)
          }
          
          begin
            # We define hooks so we can call the script block as a batch. 
            # We intentionally set and unset the hooks so the other commands
            # (config file copy) don't get printed.
            #
            # This block gets called for every command method call.
            rbox.pre_command_hook do |cmd, args, user|
              puts command_separator(rbox.preview_command(cmd, args), user)
            end
            # And this one gets called after each command method call.
            rbox.post_command_hook do |ret|
              puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
              print_response(ret)
            end
            
            ### EXECUTE THE COMMANDS BLOCK
            rbox.batch(&proc)
            
            rbox.pre_command_hook = nil
            rbox.post_command_hook = nil
          rescue Rye::CommandError => ex
            print_response(ex)
            exit 12 unless keep_going?
          rescue Rye::CommandNotFound => ex
            STDERR.puts "  CommandNotFound: #{ex.message}".color(:red)
            STDERR.puts ex.backtrace if Rudy.debug?
            exit 12 unless keep_going?
          end
          
          # I was gettings errors about script_config_file not existing. There
          # might be a race condition when the rm command is called too quickly. 
          # It's also quite possible I'm off my rocker!
          ## NOTE: I believe this was an issue with Rye. I fixed it when I was
          ## noticing the same error in another place. It hasn't repeated. 
          ## sleep 0.1
          
          rbox.cd # reset to home dir
          rbox.rudy_tmp_rm(@@script_config_file)
        end
        
        # Return the borrowed rbox instance to the user it was provided with
        rbox.switch_user original_user
      else
        puts "Nothing to do"
      end
      
      tf.delete # delete local copy of script config
      
    end
  end
  
end;end