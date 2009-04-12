
require 'drydock'


module Rudy
  module CLI
    class NoCred < RuntimeError #:nodoc
    end
    
    class Base < Drydock::Command
      include Rudy::Huxtable
      
      attr_reader :config
      
    protected
      def init
        
        Rudy::Huxtable.update_global @global
        
        unless @@global.accesskey && @@global.secretkey
          STDERR.puts "No AWS credentials. Check your configs!"
          STDERR.puts "Try: #{$0} init"
          exit 1
        end
           
        
        if @@global.environment =~ /^prod/ && Drydock.debug?
          puts Rudy.banner("PRODUCTION ACCESS IS DISABLED IN DEBUG MODE")
          exit 1
        end
        
      end
      
      
      # Print a default header to the screen for every command.
      #
      def print_header
        puts Rudy::CLI.generate_header(@@global, @@config)
        unless @@global.quiet
          puts # a new line
          
          if @@global.environment == "prod"
            msg = "YOU ARE PLAYING WITH PRODUCTION"
            puts Rudy.banner(msg, :huge, :red), $/
          end
        
          puts Rudy.banner("THIS IS EC2"), $/ if Rudy.in_situ?
        end
      end
      

    end



    def self.generate_header(global, config)
      header = StringIO.new
      title = "RUDY v#{Rudy::VERSION}" unless global.quiet
      now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      criteria = []
      [:zone, :environment, :role, :position].each do |n|
        val = global.send(n)
        next unless val
        criteria << "#{n.to_s.slice(0,1).att :normal}:#{val.to_s.bright}"
      end
      if config.accounts && config.accounts.aws
        header.puts '%s -- %s -- %s UTC' % [title, config.accounts.aws.name, now_utc] unless global.quiet
        header.puts '[%s]' % criteria.join("  ") unless global.quiet
      end
      
      header.rewind
      header.read
    end


  end
end


Rudy.require_glob(RUDY_LIB, 'rudy', 'cli', '**', '*.rb')


