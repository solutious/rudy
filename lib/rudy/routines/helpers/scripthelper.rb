require 'tempfile'

module Rudy; module Routines; 
  #--
  # TODO: Rename to ShellHelper
  #++
  module ScriptHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self
    
    Rudy::Routines.add_helper :local, self
    Rudy::Routines.add_helper :remote, self
        
    def execute(type, definition)
      self.send type, definition
    end
    
    def local(routine, sconf, rbox, option=nil, argv=nil)
      execute_command(:local, routine, sconf, 'localhost', rbox, option, argv)
    end
    def local?(routine)
      # local generally doesn't take a user name like the remote
      # block so we add it here (unless the user did specify it)
      routine[:local] = { 
        Rudy.sysinfo.user.to_sym => routine.delete(:local) 
      } if routine[:local].is_a?(Proc)
      execute_command?(:local, routine)
    end
    
    
    def remote(routine, sconf, machine, rbox, option=nil, argv=nil)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:remote, routine, sconf, machine.name, rbox, option, argv)
    end
    def remote?(routine); execute_command?(:remote, routine); end

  
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
        choice = Annoy.get_user_input('(S)kip (A)bort: ') || ''
         if choice.match(/\AS/i)
           return
         else
           exit 12
         end
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
            
          rescue Rye::CommandError => ex
            print_response(ex)
            choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ') || ''
             if choice.match(/\AS/i)
               return
             elsif choice.match(/\AR/i)
               retry
             else
               exit 12
             end
          rescue Rye::CommandNotFound => ex
            STDERR.puts "  CommandNotFound: #{ex.message}".color(:red)
            STDERR.puts ex.backtrace if Rudy.debug?
            choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ') || ''
             if choice.match(/\AS/i)
               return
             elsif choice.match(/\AR/i)
               retry
             else
               exit 12
             end
          ensure
            rbox.pre_command_hook = nil
            rbox.post_command_hook = nil
            rbox.enable_safe_mode  # In case it was disabled
          end
          
          rbox.cd # reset to home dir
        end
        
        # Return the borrowed rbox instance to the user it was provided with
        rbox.switch_user original_user
      
      ##else
      ##  puts "Nothing to do"
      ##end
      
      
    end
  end
  
end;end