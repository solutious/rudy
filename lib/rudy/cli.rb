
require 'drydock'


module Rudy
    
  # = CLI
  # 
  # These classes provide the functionality for the Command
  # line interfaces. See the bin/ files if you're interested. 
  # 
  module CLI
    class NoCred < RuntimeError #:nodoc
    end
    
    class Output < Storable
      # TODO: Use for all CLI responses
      # Messages and errors should be in @@global.format
      # Should print messages as they come
    end
    
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
        @@global.yes ? Annoy.enable_skip : Annoy.disable_skip
        
        unless @@global.accesskey && @@global.secretkey
          STDERR.puts "No AWS credentials. Check your configs!"
          STDERR.puts "Try: rudy init"
          exit 1
        end
        
        if @@global.environment =~ /^prod/ && Drydock.debug?
          puts Rudy::Utils.banner("PRODUCTION ACCESS IS DISABLED IN DEBUG MODE")
          exit 1
        end
        
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
          puts Rudy::Utils.banner("THIS IS EC2"), $/ if Rudy.in_situ?
        end
      end
      
      def machine_separator(name, awsid)
        ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
      end
      
    end

    def self.generate_header(global, config)
      return "" if global.quiet
      header = StringIO.new
      title, name = "RUDY v#{Rudy::VERSION}", config.accounts.aws.name
      now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      criteria = []
      [:region, :zone, :environment, :role, :position].each do |n|
        key, val = n.to_s.slice(0,1).att, global.send(n) 
        key = 'R' if n == :region
        next unless val
        criteria << "#{key.att}:#{val.to_s.bright}"
      end
      if config.accounts && config.accounts.aws
        if global.verbose > 0
          header.puts '%s -- %s -- %s UTC' % [title, name, now_utc]
        end
        header.puts '[%s]' % [criteria.join("  ")], $/
      end
      header.rewind
      header.read
    end


    # A base for all Drydock executables (bin/rudy etc...). 
    class Base
      extend Drydock
      
      before do |obj|
        # Don't print Rudy header unless requested to
        obj.global.print_header = false  if (obj.global.verbose == 0)
        @start = Time.now
      end

      after do |obj|  
        if obj.global.verbose > 0
          puts
          @elapsed = Time.now - @start
          puts "Elapsed: %.2f seconds" % @elapsed.to_f if @elapsed > 0.1
        end
      end
      
      
      # These globals are used by all bin/ executables
      global :A, :accesskey, String, "AWS Access Key"
      global :S, :secretkey, String, "AWS Secret Access Key"
      global :R, :region, String, "Amazon service region (e.g. #{Rudy::DEFAULT_REGION})"
      global :z, :zone, String, "Amazon Availability zone (e.g. #{Rudy::DEFAULT_ZONE})"
      global :u, :user, String, "Provide a username (ie: #{Rudy.sysinfo.user})"
      global :l, :localhost, String, "Provide a localhost (e.g. #{Rudy.sysinfo.hostname})"
      global :k, :pkey, String, "Path to the private SSH key"
      global :f, :format, String, "Output format"
      global :n, :nocolor, "Disable output colors"
      global :C, :config, String, "Specify another configuration file to read (e.g. #{Rudy::CONFIG_FILE})"
      global :Y, :yes, "Assume a correct answer to confirmation questions"
      global :q, :quiet, "Run with less output"
     #global :O, :offline, "Be cool about the internet being down"
      global :v, :verbose, "Increase verbosity of output (e.g. -v or -vv or -vvv)" do
        @verbose ||= 0
        @verbose += 1
      end
      global :V, :version, "Display version number" do
        puts "Rudy version: #{Rudy::VERSION}"
        exit 0
      end
      
      debug :off
    end
    
    
  end

end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'cli', '**', '*.rb')


