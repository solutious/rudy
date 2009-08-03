

module Rudy::CLI
  
  class CommandBase < Drydock::Command
    include Rudy::Huxtable

    attr_reader :config

  protected
    def init

      if Drydock.debug?
        #Caesars.enable_debug
        Rudy.enable_debug
      end

      # The CLI wants output!
      Rudy::Huxtable.update_logger STDOUT

      # Send The Huxtables the global values from the command-line
      Rudy::Huxtable.update_global @global

      # Reload configuration. This must come after update_global 
      # so it will catch the @@global.config path (if supplied).
      begin
        Rudy::Huxtable.update_config
      rescue Caesars::SyntaxError => ex
        STDERR.puts ex.message
        STDERR.puts ex.backtrace if @@global.verbose > 0
        exit 81
      end

      @@global.nocolor ? String.disable_color : String.enable_color
      @@global.auto ? Annoy.enable_skip : Annoy.disable_skip

      unless @@global.accesskey && @@global.secretkey
        STDERR.puts "No AWS credentials. Check your configs!"
        STDERR.puts "Try: rudy init"
        exit 1
      end

      if @@global.environment =~ /^prod/ && Rudy.debug?
        puts Rudy::Utils.banner("PRODUCTION ACCESS IS DISABLED IN DEBUG MODE")
        exit 1
      end

      if @@global.verbose >= 4    # -vvvv
        format = @@global.format == :json ? :json : :yaml
        gcopy = @@global.dup
        gcopy.secretkey = "[HIDDEN]"
        puts "# GLOBALS: ", gcopy.dump(format)
      end
      
      Rudy::Metadata.connect @@global.accesskey, @@global.secretkey, @@global.region
      Rudy::AWS::EC2.connect @@global.accesskey, @@global.secretkey, @@global.region
    end

    def execute_action(emsg="Failed", &action)
      begin
        ret = action.call
        raise emsg unless ret
        ret
      rescue Rudy::AWS::EC2::NoAMI => ex
        raise Drydock::OptError.new('-a', @alias)
      end
    end

    def execute_check(level=:medium)
      ret = Annoy.are_you_sure?(level)
      exit 0 unless ret
      ret
    end

    # Print a default header to the screen for every command.
    #
    def print_header

      # Send The Huxtables the global values again because they could be
      # updated after initialization but before the command was executed
      Rudy::Huxtable.update_global @global

      puts Rudy::CLI.generate_header(@@global, @@config) if @@global.print_header

      unless @@global.quiet
        if @@global.environment == "prod"
          msg = "YOU ARE PLAYING WITH PRODUCTION"
          puts Rudy::Utils.banner(msg, :normal), $/
        end
      end
    end

    def machine_separator(name, awsid)
      ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end

  end
end