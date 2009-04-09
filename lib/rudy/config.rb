
module Rudy
  require 'caesars'
  
  class Config < Caesars::Config
    require 'rudy/config/objects'
    
    dsl Rudy::Config::Accounts::DSL
    dsl Rudy::Config::Defaults::DSL
    dsl Rudy::Config::Routines::DSL
    dsl Rudy::Config::Machines::DSL
    dsl Rudy::Config::Networks::DSL
    
    # TODO: auto-generate in caesars
    def accounts?; self.respond_to?(:accounts) && !self[:accounts].nil?; end
    def defaults?; self.respond_to?(:defaults) && !self[:defaults].nil?; end
    def machines?; self.respond_to?(:machines) && !self[:machines].nil?; end
    def routines?; self.respond_to?(:routines) && !self[:routines].nil?; end
    def networks?; self.respond_to?(:networks) && !self[:networks].nil?; end
    
    def postprocess
      #raise "There is no AWS info configured" if self.accounts.nil?
      
      # These don't work anymore. Caesars bug?
      #if accounts? && !self.accounts.aws.nil?
      #  self.accounts.aws.cert &&= File.expand_path(self.accounts.aws.cert) 
      #  self.accounts.aws.privatekey &&= File.expand_path(self.accounts.aws.privatekey)
      #end
    end
    
    def look_and_load(adhoc_path=nil)
      cwd = Dir.pwd
      cwd_path = File.join(cwd, '.rudy', 'config')
      
      # Attempt to load the core configuration file first.
      # The "core" config file can have any or all configuration
      # but it should generally only contain the access identifiers
      # and defaults. That's why we only load one of them. 
      core_config_paths = [adhoc_path, cwd_path, RUDY_CONFIG_FILE]
      core_config_paths.each do |path|
        next unless path && File.exists?(path)
        @paths << path
        break
      end
      
      # Rudy then looks for the rest of the config in these locations
      @paths += Dir.glob(File.join('/etc', 'rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, 'Rudyfile')) || []
      @paths += Dir.glob(File.join(cwd, 'config', 'rudy', '*.rb')) || []
      @paths += Dir.glob(File.join(cwd, '.rudy', '*.rb')) || []
      @paths &&= @paths.uniq
      refresh
    end

    
    
    def self.init_config_dir
      
      unless File.exists?(RUDY_CONFIG_DIR)
        puts "Creating #{RUDY_CONFIG_DIR}"
        Dir.mkdir(RUDY_CONFIG_DIR, 0700)
      end

      unless File.exists?(RUDY_CONFIG_FILE)
        puts "Creating #{RUDY_CONFIG_FILE}"
        rudy_config = Rudy::Utils.without_indent %Q{
          # Amazon Web Services 
          # Account access indentifiers.
          accounts do
            aws do
              name "Rudy Default"
              accountnum ""
              accesskey ""
              secretkey ""
              privatekey "~/path/2/pk-xxxx.pem"
              cert "~/path/2/cert-xxxx.pem"
            end
          end

          # Machine Configuration
          # Specify your private keys here. These can be defined globally
          # or by environment and role like in machines.rb.
          machines do
            users do
              #root :keypair => "path/2/root-private-key"
            end
            zone :"us-east-1b" do
              ami 'ami-235fba4a'    # Amazon Getting Started AMI (US)
            end
            zone :"eu-west-1b" do
              ami 'ami-e40f2790'    # Amazon Getting Started AMI (EU)
            end
          end
          
          # Global Defaults 
          # Define the values to use unless otherwise specified on the command-line. 
          defaults do
            region :"us-east-1" 
            zone :"us-east-1b"
            environment :stage
            role :app
            position 01
            user ENV['USER'].to_sym
          end
        }
        Rudy::Utils.write_to_file(RUDY_CONFIG_FILE, rudy_config, 'w', 0600)
      end
    end

  end
end


