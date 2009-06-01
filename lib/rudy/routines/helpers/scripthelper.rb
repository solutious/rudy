require 'tempfile'

module Rudy; module Routines; 
  #--
  # TODO: Rename to ShellHelper
  #++
  module ScriptHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self

    @@script_types = [:after, :before, :after_local, :before_local, :script, :script_local]
    @@script_config_file_name = "rudy-config.yml"
    
    # TODO: refactor using this_method
    
    def before_local(routine, sconf, rbox, option=nil, argv=nil)
      execute_command(:before_local, routine, sconf, 'localhost', rbox, option, argv)
    end
    def before_local?(routine)
      # before_local generally doesn't take a user name like the remote
      # before block so we add it here (unless the user did specify it)
      routine[:before_local] = { 
        Rudy.sysinfo.user.to_sym => routine.delete(:before_local) 
      } if routine[:before_local].is_a?(Proc)
      execute_command?(:before_local, routine)
    end
    def script_local(routine, sconf, rbox, option=nil, argv=nil)
      execute_command(:script_local, routine, sconf, 'localhost', rbox, option, argv)
    end
    def script_local?(routine)
      # before_local generally doesn't take a user name like the remote
      # before block so we add it here (unless the user did specify it)
      routine[:script_local] = { 
        Rudy.sysinfo.user.to_sym => routine.delete(:script_local) 
      } if routine[:script_local].is_a?(Proc)
      execute_command?(:script_local, routine)
    end
    
    def after_local(routine, sconf, rbox, option=nil, argv=nil)
      execute_command(:after_local, routine, sconf, 'localhost', rbox, option, argv)
    end
    def after_local?(routine)
      routine[:after_local] = {                 # See before_local note
        Rudy.sysinfo.user.to_sym => routine.delete(:after_local) 
      } if routine[:after_local].is_a?(Proc)
      execute_command?(:after_local, routine)
    end
    
    def before(routine, sconf, machine, rbox, option=nil, argv=nil)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:before, routine, sconf, machine.name, rbox, option, argv)
    end
    def before?(routine); execute_command?(:before, routine); end
    
    def after(routine, sconf, machine, rbox, option=nil, argv=nil)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:after, routine, sconf, machine.name, rbox, option, argv)
    end
    def after?(routine); execute_command?(:after, routine); end
    
    def script(routine, sconf, machine, rbox, option=nil, argv=nil)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:script, routine, sconf, machine.name, rbox, option, argv)
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
      unless routine[timing].kind_of?(Hash)
        STDERR.puts "No user supplied for #{timing} block".color(:red)
        exit 12 unless keep_going?
        return false
      end
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
    def execute_command(timing, routine, sconf, hostname, rbox, option=nil, argv=nil)
      raise "ScriptHelper: Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      raise "ScriptHelper: #{timing}?" unless @@script_types.member?(timing)
      
      # The config file that gets created on each remote machine
      # will be created in the user's home directory. 
      script_config_remote_path = File.join(rbox.getenv['HOME'], @@script_config_file_name)
      
      if sconf && !sconf.empty?
        tf = Tempfile.new(@@script_config_file_name)
        Rudy::Utils.write_to_file(tf.path, sconf.to_hash.to_yaml, 'w')
      end
      
      # Do we need to run this again? It's called in generic_routine_runner
      ##if execute_command?(timing, routine) # i.e. before_local?

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
          
          trap_rbox_errors {
            # We need to create the config file for every script, 
            # b/c the user may change and it would not be accessible.
            # We turn off safe mode so we can write the config file via SSH. 
            # This will need to use SCP eventually; it is unsafe and error prone.
            # TODO: Replace with rbox.upload. Make it safe again!
            conf_str = StringIO.new
            conf_str.puts sconf.to_hash.to_yaml
            rbox.upload(conf_str, script_config_remote_path)
            rbox.chmod(600, script_config_remote_path)
          }
          
          begin
            # We define hooks so we can still print each command and its output
            # when running the command blocks. NOTE: We only print this in
            # verbosity mode. We intentionally set and unset the hooks 
            # so the other commands (config file copy) don't get printed.
            if @@global.verbose > 0
              # This block gets called for every command method call.
              rbox.pre_command_hook do |cmd, args, user, host|
                puts command_separator(rbox.preview_command(cmd, args), user, host)
              end
            end
            if @@global.verbose > 1
              # And this one gets called after each command method call.
              rbox.post_command_hook do |ret|
                puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
                print_response(ret)
              end
            end
            
            ### EXECUTE THE COMMANDS BLOCK
            rbox.batch(option, argv, &proc)
            
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
          
          rbox.cd # reset to home dir
          rbox.rudy_tmp_rm(:f, script_config_remote_path)  # -f to ignore errors
        end
        
        # Return the borrowed rbox instance to the user it was provided with
        rbox.switch_user original_user
      
      ##else
      ##  puts "Nothing to do"
      ##end
      
      tf.delete # delete local copy of script config
      
    end
  end
  
end;end