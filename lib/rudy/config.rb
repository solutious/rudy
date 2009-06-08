
module Rudy
  require 'caesars'
  
  class Config < Caesars::Config
    require 'rudy/config/objects'
    
    dsl Rudy::Config::Accounts::DSL    
    dsl Rudy::Config::Defaults::DSL    
    dsl Rudy::Config::Routines::DSL    # Organized processes
    dsl Rudy::Config::Machines::DSL    # Organized instances
    dsl Rudy::Config::Commands::DSL    # Custom SSH commands
    #dsl Rudy::Config::Networks::DSL    # Network design
    #dsl Rudy::Config::Controls::DSL    # Network access
    #dsl Rudy::Config::Services::DSL    # Stuff running on ports
    
    def accounts?; self.respond_to?(:accounts) && !self[:accounts].nil?; end #a
    def defaults?; self.respond_to?(:defaults) && !self[:defaults].nil?; end #u
    def machines?; self.respond_to?(:machines) && !self[:machines].nil?; end #t
    def commands?; self.respond_to?(:commands) && !self[:commands].nil?; end #o
    def routines?; self.respond_to?(:routines) && !self[:routines].nil?; end #g
    #def networks?; self.respond_to?(:networks) && !self[:networks].nil?; end #e
    #def controls?; self.respond_to?(:controls) && !self[:controls].nil?; end #n
    #def services?; self.respond_to?(:services) && !self[:services].nil?; end #!
    
    # This method is called by Caesars::Config.refresh for every DSL 
    # file that is loaded and parsed. If we want to run processing
    # for a particular config (machines, @routines, etc...) we can
    # do it here. Just wait until the instance variable is not nil.
    def postprocess
      #raise "There is no AWS info configured" if self.accounts.nil?
      
      # These don't work anymore. Caesars bug?
      #if accounts? && !self.accounts.aws.nil?
      #  self.accounts.aws.cert &&= File.expand_path(self.accounts.aws.cert) 
      #  self.accounts.aws.privatekey &&= File.expand_path(self.accounts.aws.privatekey)
      #end
      
      # The commands config modifies the way the routines configs
      # should be parsed. This happens in the postprocess method
      # we call here. We can't guarantee this will run before the
      # routines config is loaded so this postprocess method will
      # raise a Caesars::Config::ForceRefresh exception if that's
      # the case. Rudy::Config::Commands knows to only raise the
      # exception one time (using a boolean flag in a class var).
      @commands.postprocess if @commands
      @defaults.postprocess if @defaults
      
      # default will be nil if non was specified. We at least want the object.
      @defaults = Rudy::Config::Defaults.new if @defaults.nil?
    end
    
    def look_and_load(adhoc_path=nil)
      cwd = Dir.pwd
      cwd_path = File.join(cwd, '.rudy', 'config')
      
      # Attempt to load the core configuration file first.
      # The "core" config file can have any or all configuration
      # but it should generally only contain the access identifiers
      # and defaults. That's why we only load one of them. 
      core_config_paths = [adhoc_path, cwd_path, Rudy::CONFIG_FILE]
      core_config_paths.each do |path|
        next unless path && File.exists?(path)
        @paths << path
        break
      end
      
      typelist = self.keys.collect { |g| "#{g}.rb" }.join(',')
      
      # Rudy then looks for the rest of the config in these locations
      @paths += Dir.glob(File.join(Rudy.sysinfo.home, '.rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, 'Rudyfile')) || []
      @paths += Dir.glob(File.join(cwd, 'config', 'rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, '.rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, "{#{typelist}}")) || []
      @paths += Dir.glob(File.join('/etc', 'rudy', '*.rb')) || []
      @paths &&= @paths.uniq
      
      refresh
    end

    
    def self.init_config_dir
      
      unless File.exists?(Rudy::CONFIG_DIR)
        puts "Creating #{Rudy::CONFIG_DIR}"
        Dir.mkdir(Rudy::CONFIG_DIR, 0700)
      end

      unless File.exists?(Rudy::CONFIG_FILE)
        puts "Creating #{Rudy::CONFIG_FILE}"
        rudy_config = Rudy::Utils.without_indent %Q{
          accounts do                           # Account Access Indentifiers
            aws do                              # amazon web services 
              name "Rudy Default"
              accountnum ""
              accesskey ""
              secretkey ""
              privatekey "~/path/2/pk-xxxx.pem" 
              cert "~/path/2/cert-xxxx.pem"
            end
          end
        }
        Rudy::Utils.write_to_file(Rudy::CONFIG_FILE, rudy_config, 'w', 0600)
      end
    end

  end
end


