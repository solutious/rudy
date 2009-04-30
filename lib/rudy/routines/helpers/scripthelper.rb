require 'tempfile'

module Rudy; module Routines; 
  #--
  # TODO: Rename to ShellHelper
  #++
  module ScriptHelper
    include Rudy::Routines::HelperBase  # TODO: use execute_rbox_command
    extend self

    @@script_types = [:after, :before, :after_local, :before_local]
    @@script_config_file = "rudy-config.yml"
    
    def before_local(routine, sconf, rbox)
      
      # before_local generally doesn't take a user name like the remote
      # before block so we add it here (unless the user did specify it)
      routine[:before_local] = { 
        rbox.user.to_sym => routine.delete(:before_local) 
      } unless routine.has_key?(rbox.user.to_sym) # use routine[timing].deepest_point ?
      execute_command(:before_local, routine, sconf, 'localhost', rbox)
    end
    def before_local?(routine); execute_command?(:before_local, routine); end
      
    def after_local(routine, sconf, rbox)
      routine[:after_local] = {                 # See before_local note
        rbox.user.to_sym => routine.delete(:after_local) 
      } unless routine.has_key?(rbox.user.to_sym)
      execute_command(:after_local, routine, sconf, 'localhost', rbox)
    end
    def after_local?(routine); execute_command?(:after_local, routine); end
      
    
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
    
  
  private  
    
    # Does the routine have the requested script type?
    # * +timing+ is one of: after, before, after_local, before_local
    # * +routine+ a single routine hash (startup, shutdown, etc...)
    # Prints notice to STDERR if there's an empty conf hash
    def execute_command?(timing, routine)
      hasconf = (routine.is_a?(Caesars::Hash) && routine.has_key?(timing))
      return false unless hasconf
      p "#{timing}: #{routine[timing].deepest_point}"
      p routine[timing]
      routine[timing].each_pair do |user,conf|
        if conf.empty? 
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
      
      # We need to explicitly add the rm command for rbox so we
      # can delete the script config file when we're done. This
      # add the method on for the instance of rbox we are using. 
      def rbox.rm(*args); cmd('rm', args); end
      
      if execute_command?(timing, routine) # i.e. before_local?
        
        original_user = rbox.user
        users = routine[timing] || {}
        users.each_pair do |user, commands|
          
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
        
          commands.each_pair do |command, calls|
            # If a command is only referred to once and it has no arguments
            # defined, we force it through by making an array with one element.
            calls = [[]] if calls.empty?
            calls.each do |args|
              puts command_separator(rbox.preview_command(command, args), user)
              execute_rbox_command { 
                ret = rbox.send(command, args) 
              }
            end
          end
          
          # I was gettings errors about script_config_file not existing. There
          # might be a race condition when the rm command is called too quickly. 
          # It's also quite possible I'm off my rocker!
          sleep 0.1
          
          rbox.cd # reset to home dir
          rbox.rm(@@script_config_file)
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