
require 'drydock'

module Rudy
  module CLI
    class NoCred < RuntimeError #:nodoc
    end
    
    class Output < Storable
      # Use for all CLI responses
      # Messages and errors should be in @@global.format
      # Should print messages as they come
    end
    
    class CommandBase < Drydock::Command
      include Rudy::Huxtable
      
      attr_reader :config
      
    protected
      def init
        
        # Send The Huxtables the global values from the command-line
        Rudy::Huxtable.update_global @global
        
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
        ret = Annoy.are_you_sure?(:medium)
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
            puts Rudy::Utils.banner(msg, :huge, :red), $/
          end
          puts Rudy::Utils.banner("THIS IS EC2"), $/ if Rudy.in_situ?
        end
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
      global :R, :region, String, "Amazon service region (ie: #{Rudy::DEFAULT_REGION})"
      global :z, :zone, String, "Amazon Availability zone (ie: #{Rudy::DEFAULT_ZONE})"
      global :f, :format, String, "Output format"
      global :n, :nocolor, "Disable output colors"
      global :C, :config, String, "Specify another configuration file to read (ie: #{Rudy::CONFIG_FILE})"
      global :Y, :yes, "Assume a correct answer to confirmation questions"
      global :q, :quiet, "Run with less output"
      global :v, :verbose, "Increase verbosity of output (i.e. -v or -vv or -vvv)" do
        @verbose ||= 0
        @verbose += 1
      end
      global :V, :version, "Display version number" do
        puts "Rudy version: #{Rudy::VERSION}"
        exit 0
      end
      
    end
    
    
  end

end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'cli', '**', '*.rb')


