
module Rudy
  class UnknownInstance < RuntimeError; end
end

module Rudy
  module CLI
    class NoCred < RuntimeError; end;
    
    class Base < Drydock::Command

      attr_reader :scm
  
      attr_reader :rscripts
      attr_reader :domains
      attr_reader :machine_images
      
      attr_reader :config
      
      
      def init
        
        
        raise "PRODUCTION ACCESS IS DISABLED IN DEBUG MODE" if @global.environment == "prod" && Drydock.debug?
        
        @global.config ||= RUDY_CONFIG_FILE
        
        unless File.exists?(@global.config)
          init_config_dir
        end
        
        @config = Rudy::Config.new(@global.config, {:verbose => (@global.verbose > 0)} )
        @config.look_and_load
        
        raise "There is no machine group configured" if @config.machines.nil?
        raise "There is no AWS info configured" if @config.awsinfo.nil?
        
        
        @global.accesskey ||= @config.awsinfo.accesskey || ENV['AWS_ACCESS_KEY']
        @global.secretkey ||= @config.awsinfo.secretkey || ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
        @global.account ||= @config.awsinfo.account || ENV['AWS_ACCOUNT_NUMBER'] 
        
        @global.cert ||= @config.awsinfo.cert || ENV['EC2_CERT']
        @global.privatekey ||= @config.awsinfo.privatekey || ENV['EC2_PRIVATE_KEY']
        
        @global.cert = File.expand_path(@global.cert || '')
        @global.privatekey = File.expand_path(@global.privatekey || '')
        
        @global.region ||= @config.defaults.region || DEFAULT_REGION
        @global.zone ||= @config.defaults.zone || DEFAULT_ZONE
        @global.environment ||= @config.defaults.environment || DEFAULT_ENVIRONMENT
        @global.role ||= @config.defaults.role || DEFAULT_ROLE
        @global.position ||= @config.defaults.position || DEFAULT_POSITION
        @global.user ||= @config.defaults.user || DEFAULT_USER
        
        @global.local_user = ENV['USER'] || :user
        @global.local_hostname = Socket.gethostname || :host
        
        
        if @global.verbose > 1
          puts "GLOBALS:"
          @global.marshal_dump.each_pair do |n,v|
            puts "#{n}: #{v}"
          end
          ["machines", "routines"].each do |type|
            puts "#{$/*2}#{type.upcase}:"
            val = @config.send(type).find_deferred(@global.environment, @global.role)
            puts val.to_hash.to_yaml
          end
          puts
        end
        
        
        # TODO: enforce home directory permissions
        #if File.exists?(RUDY_CONFIG_DIR)
        #  puts "Checking #{check_environment} permissions..."
        #end
        

      end
      protected :init
      

      
      
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
        
        puts unless @global.quiet
        
        if (@global.environment == "prod") 
          msg = without_indent %q(
          =======================================================
          =======================================================
          !!!!!!!!!   YOU ARE PLAYING WITH PRODUCTION   !!!!!!!!!
          =======================================================
          =======================================================)
          puts msg.colour(:red).bgcolour(:white).att(:bright), $/  unless @global.quiet
          
        end
        
        if Rudy.in_situ?
          msg = %q(============ THIS IS EC2 ============)
          puts msg.colour(:blue).bgcolour(:white).att(:bright), $/ unless @global.quiet
        end
        
      end
      
      def print_footer
        
      end
      

      private 

        
        def print_image(img)
          puts '-'*60
          puts "Image: #{img[:aws_id].att(:bright)}"
          img.each_pair do |key, value|
             printf(" %22s: %s#{$/}", key, value) if value
           end
          puts
        end
        
        def print_disk(disk, backups=[])
          puts '-'*60
          puts "Disk: #{disk.name.att(:bright)}"
          puts disk.to_s
          puts "#{backups.size} most recent backups:", backups.collect { |back| "#{back.nice_time} (#{back.awsid})" }
          puts
        end
        
        
        def print_volume(vol, disk)
          puts '-'*60
          puts "Volume: #{vol[:aws_id].att(:bright)} (disk: #{disk.name if disk})"
          vol.each_pair do |key, value|
             printf(" %22s: %s#{$/}", key, value) if value
           end
          puts
        end
        
        
        def init_config_dir
          unless File.exists?(RUDY_CONFIG_DIR)
            puts "Creating #{RUDY_CONFIG_DIR}"
            Dir.mkdir(RUDY_CONFIG_DIR, 0700)
          end

          unless File.exists?(RUDY_CONFIG_FILE)
            puts "Creating #{RUDY_CONFIG_FILE}"
            rudy_config = without_indent %Q{
              # Amazon Web Services 
              # Account access indentifiers.
              awsinfo do
                account ""
                accesskey ""
                secretkey ""
                privatekey "~/path/2/pk-xxxx.pem"
                cert "~/path/2/cert-xxxx.pem"
              end
              
              # Machine Configuration
              # Specify your private keys here. These can be defined globally
              # or by environment and role like in machines.rb.
              machines do
                users do
                  root :keypair => "path/2/root-private-key"
                end
              end
              
              # Routine Configuration
              # Define stuff here that you don't want to be stored in version control. 
              routines do
                config do 
                  # ...
                end
              end

              # Global Defaults 
              # Define the values to use unless otherwise specified on the command-line. 
              defaults do
                region "us-east-1" 
                zone "us-east-1b"
                environment "stage"
                role "app"
                position "01"
                user ENV['USER']
              end
            }
            write_to_file(RUDY_CONFIG_FILE, rudy_config, 'w')
          end

          #puts "Creating SimpleDB domain called #{RUDY_DOMAIN}"
          #@sdb.domains.create(RUDY_DOMAIN)
        end
    end
  end
end


