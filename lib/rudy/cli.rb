
module Rudy
  class UnknownInstance < RuntimeError; end
end

module Rudy
  module CLI
    class NoCred < RuntimeError; end;
    
    class Base < Drydock::Command

      attr_reader :config
      
    protected
      def init
        
        raise "PRODUCTION ACCESS IS DISABLED IN DEBUG MODE" if @global.environment == "prod" && Drydock.debug?
        
        @config = Rudy::Config.new
        @config.look_and_load(@global.config)
        
        raise "There is no machine group configured" if @config.machines.nil?
        
        # These are here so we can print the machine group shit in the header. 
        # The dupilcation annoys me (see Rudy::Huxtable#init_globals) and I'd
        # like to find a cleaner solution. 
        @global.region ||= @config.defaults.region || DEFAULT_REGION
        @global.zone ||= @config.defaults.zone || DEFAULT_ZONE
        @global.environment ||= @config.defaults.environment || DEFAULT_ENVIRONMENT
        @global.role ||= @config.defaults.role || DEFAULT_ROLE
        @global.position ||= @config.defaults.position || DEFAULT_POSITION
        @global.user ||= @config.defaults.user || DEFAULT_USER
        
        # This is also duplicated :[]
        String.disable_color if @global.nocolor
        Rudy.enable_quiet if @global.quiet
        
        # TODO: enforce home directory permissions
        #if File.exists?(RUDY_CONFIG_DIR)
        #  puts "Checking #{check_environment} permissions..."
        #end
        
      end
      
      
      # Print a default header to the screen for every command.
      # +cmd+ is the name of the command current running. 
      def print_header(cmd=nil)
        title = "RUDY v#{Rudy::VERSION}" unless @global.quiet
        now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
        criteria = []
        [:zone, :environment, :role, :position].each do |n|
          val = @global.send(n)
          next unless val
          criteria << "#{n.to_s.slice(0,1).att :normal}:#{val.att :bright}"
        end
        puts '%s -- %s UTC' % [title, now_utc] unless @global.quiet
        puts '[%s]' % criteria.join("  ") unless @global.quiet
        
        unless @global.quiet
          puts # a new line
          
          if @global.environment == "prod"
            msg = "YOU ARE PLAYING WITH PRODUCTION"
            puts Rudy.make_banner(msg, :huge, :red), $/
          end
        
          puts Rudy.make_banner("THIS IS EC2"), $/ #if Rudy.in_situ?
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


