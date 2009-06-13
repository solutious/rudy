

class Rudy::Config
  class Error < Rudy::Error
    def initialize(ctype, obj)
      @ctype, @obj = ctype, obj
    end
    def message; "Error in #{@ctype}: #{@obj}"; end
  end
  
  class Accounts < Caesars
    def valid?
      (!aws.nil? && !aws.accesskey.nil? && !aws.secretkey.nil?) &&
      (!aws.account.empty? && !aws.accesskey.empty? && !aws.secretkey.empty?)
    end
  end
  
  # Default configuration. All of the defaults can be overridden 
  # on the command line with global options.
  class Defaults < Caesars
    class DoubleDefined < Rudy::Config::Error
      def message; "Check your defaults config. '#{@obj}' has been defined twice"; end
    end
    # 
    # All values should scalars
    # 
    def postprocess
      self.keys.each do |k| 
        next unless self[k].is_a?(Array)
        raise Defaults::DoubleDefined.new(:defaults, k)
      end
    end
  end
  
  class Machines < Caesars; end
  
  # Modify the SSH command available in routines. The default
  # set of commands is defined by Rye::Cmd (Rudy executes all
  # SSH commands via Rye). 
  #
  # NOTE: We allow people to define their own keywords. It is
  # important that new keywords do not conflict with existing
  # Rudy keywords. Strange things may happen!
  class Commands < Caesars
    class AlreadyDefined < Rudy::Config::Error
      def message; "The command '#{@obj}' has already been defined for this project"; end
    end
    class PathNotString < Rudy::Config::Error
      def message; super << " (path must be a String)"; end
    end
    class ReservedKeyword < Rudy::Config::Error
      def message;  "%s (reserved keyword)" % [super]; end
    end
    class BadArg < Rudy::Config::Error
      def message; "Arguments for #{cmd} must be: Symbols, Strings only"; end
    end
      
    @@processed = false  
    
    ## Not used currently. May be revived. 
    ##@@allowed = []        ## Commands which have been processed
    
    forced_array :allow
    forced_array :deny
    chill :allow
    
    def init
      # We can't process the Rye::Cmd commands here because the
      # DSL hasn't been parsed yet so Rudy::Config.postprocess
      # called the following postprocess method after parsing.
    end
    
    # Process the directives specified in the commands config.
    # NOTE: This affects the processing of the routines config
    # which only works if commands is parsed first. This works
    # naturally if each config has its own file b/c Rudy loads
    # files via a glob (globs are alphabetized and "commands"
    # comes before "routines"). 
    #
    # That's obviously not good enough but for now commands
    # configuration MUST be put before routines. 
    def postprocess
      return false if @@processed
      @@processed = true  # Make sure this runs only once

      # Parses:
      # commands do
      #   allow :kill 
      #   allow :custom_script, '/full/path/2/custom_script'
      #   allow :git_clone, '/usr/bin/git', 'clone'
      # end
      # 
      # * Tells Routines to force_array on the command name.
      # This is important b/c of the way we parse commands 
      self.allow.each do |cmd|
        cmd, *args = *cmd
        
        ## Currently disabled
        ##raise AlreadyDefined.new(:commands, cmd) if @@allowed.member?(cmd)
        ##@@allowed << cmd
        
        # We can allow existing commands to be overridden but we
        # print a message to STDERR so the user knows what's up.
        if Rye::Cmd.can?(cmd)
          STDERR.puts "Redefining #{cmd}" #if @@global.verbose > 0
        end
        
        if args.last.is_a?(Proc)
          block = args.pop
          Rye::Cmd.add_command(cmd, nil, args, &block)
        else
          # If no path was specified, we can assume cmd is in the remote path so
          # when we add the method to Rye::Cmd, we'll it the path is "cmd".
          path = args.shift || cmd.to_s
          
          raise PathNotString.new(:commands, cmd) if path && !path.is_a?(String)
          
          Rye::Cmd.add_command cmd, path, args
          
        end
        
        
        ## We cannot allow new commands to be defined that conflict use known
        ## routines keywords. This is based on keywords in the current config.
        ## NOTE: We can't check for this right now b/c the routines config
        ## won't necessarily have been parsed yet. TODO: Figure it out!
        ##if Caesars.known_symbol_by_glass?(:routines, cmd)
        ##  raise ReservedKeyword.new(:commands, cmd)
        ##end
        
      end
  
      ## NOTE: We now process command blocks as Procs rather than individual commands.
      ## There's currently no need to ForceRefresh here
      ##raise Caesars::Config::ForceRefresh.new(:routines)
    end
  end
  
  class Routines < Caesars
    
    # Disk routines
    forced_hash :create
    forced_hash :destroy
    forced_hash :restore
    forced_hash :umount
    forced_hash :unmount
    forced_hash :mount
    forced_hash :attach
    forced_hash :detach
    forced_hash :snapshot
    forced_hash :restore
    
    # Script blocks
    forced_hash :before          # TODO: Clean for 0.9
    forced_hash :after         
    forced_hash :local
    forced_hash :remote
    forced_hash :script_local
    forced_hash :before_local  
    forced_hash :after_local     # We force hash the script keywords b/c
    forced_hash :script          # we want them to store the usernames 
    chill :before                # as hash keys. 
    chill :after                 # We also chill them b/c we want to execute
    chill :before_local          # the command blocks with an instance_eval
    chill :after_local           # inside a Rye::Box object.
    chill :script
    chill :script_local
    chill :local
    chill :remote
        
    # Version control systems
    forced_hash :git
    forced_hash :svn
    
    def init      
    end

  end
  
  
  class Networks < Caesars #:nodoc:all
  end
  class Controls < Caesars #:nodoc:all
  end
  class Services < Caesars #:nodoc:all
  end
end