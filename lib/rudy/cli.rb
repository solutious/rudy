
module Rudy
  class UnknownInstance < RuntimeError #:nodoc
  end
end

module Rudy
  
  # 
  module CLI
    class NoCred < RuntimeError #:nodoc
    end
    
    class Base < Drydock::Command

      attr_reader :config
      
    protected
      def init
        
        # This is duplicated in Huxtable :[
        String.disable_color if @global.nocolor
        Rudy.enable_quiet if @global.quiet
        
        @config = Rudy::Config.new
        @config.look_and_load(@global.config)

        unless @config.accounts && @config.accounts.aws && @config.accounts.aws.accesskey
          STDERR.puts "No AWS credentials. Check your configs!"
          STDERR.puts "Try: #{$0} init"
          exit 1
        end
                
        # EVERYTHING BELOW THIS LINE IS ATROCIOUS 
        
        # These are here so we can print the machine group shit in the header. 
        # The dupilcation annoys me (see Rudy::Huxtable#init_globals) and I'd
        # like to find a cleaner solution. 
        if @config.defaults
          @global.region ||= @config.defaults.region 
          @global.zone ||= @config.defaults.zone 
          @global.environment ||= @config.defaults.environment
          @global.role ||= @config.defaults.role 
          @global.position ||= @config.defaults.position 
          @global.user ||= @config.defaults.user
        end
        
        @global.region ||= DEFAULT_REGION
        @global.zone ||= DEFAULT_ZONE
        @global.environment ||= DEFAULT_ENVIRONMENT
        @global.role ||= DEFAULT_ROLE
        @global.position ||= DEFAULT_POSITION
        @global.user ||= DEFAULT_USER
        
        
        if @global.verbose > 1
          puts "CONFIGS: ", @config.paths, $/
          
          puts "GLOBALS:"
          @global.marshal_dump.each_pair do |n,v|
            puts "#{n}: #{v}"
          end
          ["machines", "routines"].each do |type|
            puts "#{$/*2}#{type.upcase}:"
            val = @config.send(type).find_deferred(@global.environment, @global.role)
            puts val.to_hash.to_yaml if val
          end
          puts
        end
        
        if @global.environment =~ /^prod/ && Drydock.debug?
          puts Rudy.banner("PRODUCTION ACCESS IS DISABLED IN DEBUG MODE")
          exit 1
        end

        
        # TODO: enforce home directory permissions
        #if File.exists?(RUDY_CONFIG_DIR)
        #  puts "Checking #{check_environment} permissions..."
        #end
        
      end
      
      
      # Print a default header to the screen for every command.
      #
      # * +cmd+ is the name of the command current running. 
      def print_header(cmd=nil)
        title = "RUDY v#{Rudy::VERSION}" unless @global.quiet
        now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
        criteria = []
        [:zone, :environment, :role, :position].each do |n|
          val = @global.send(n)
          next unless val
          criteria << "#{n.to_s.slice(0,1).att :normal}:#{val.to_s.bright}"
        end
        if @config.accounts && @config.accounts.aws
          puts '%s -- %s -- %s UTC' % [title, @config.accounts.aws.name, now_utc] unless @global.quiet
          puts '[%s]' % criteria.join("  ") unless @global.quiet
        end
        
        unless @global.quiet
          puts # a new line
          
          if @global.environment == "prod"
            msg = "YOU ARE PLAYING WITH PRODUCTION"
            puts Rudy.banner(msg, :huge, :red), $/
          end
        
          puts Rudy.banner("THIS IS EC2"), $/ if Rudy.in_situ?
        end
        
        
      end

    end
  end
end

# Require EC2, S3, Simple DB class
begin
  # TODO: Use autoload
  Dir.glob(File.join(RUDY_LIB, 'rudy', 'cli', "*.rb")).each do |path|
    require path
  end
rescue LoadError => ex
  puts "Error: #{ex.message}"
  exit 1
end


