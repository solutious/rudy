


module Rudy
  module Huxtable
    @@debug = false
    
    attr_accessor :config
    attr_accessor :global
    attr_accessor :logger
    
    def initialize(opts={})
      opts = { :config => nil, :logger => STDERR, :global => OpenStruct.new}.merge(opts)
      
      # Set instance variables
      opts.each_pair { |n,v| self.send("#{n}=", v) if self.respond_to?("#{n}=") }
      
      unless @config
        @config = Rudy::Config.new
        @config.look_and_load(@global.config)
      end
      
      init_globals
      
      unless File.exists?(RUDY_CONFIG_FILE)
        init_config_dir
      end
      
      if has_keys?
        @ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
        @sdb = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
        #@s3 = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
      end
    end
    
    def init_globals
      @global.verbose ||= 0
      
      @global.cert = File.expand_path(@global.cert || '')
      @global.privatekey = File.expand_path(@global.privatekey || '')
      
      if @config.defaults
        @global.region ||= @config.defaults.region
        @global.zone ||= @config.defaults.zone
        @global.environment ||= @config.defaults.environment
        @global.role ||= @config.defaults.role 
        @global.position ||= @config.defaults.position
        @global.user ||= @config.defaults.user 
        @global.nocolor = @config.defaults.nocolor
        @global.quiet = @config.defaults.quiet
      end
      
      @global.region ||= DEFAULT_REGION
      @global.zone ||= DEFAULT_ZONE
      @global.environment ||= DEFAULT_ENVIRONMENT
      @global.role ||= DEFAULT_ROLE
      @global.position ||= DEFAULT_POSITION
      @global.user ||= DEFAULT_USER
      @global.nocolor = false
      @global.quiet = false
      
      if @config.awsinfo
        @global.accesskey ||= @config.awsinfo.accesskey 
        @global.secretkey ||= @config.awsinfo.secretkey 
        @global.account ||= @config.awsinfo.account
        
        @global.cert ||= @config.awsinfo.cert
        @global.privatekey ||= @config.awsinfo.privatekey
      end
      
      @global.accesskey ||= ENV['AWS_ACCESS_KEY']
      @global.secretkey ||= ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
      @global.account ||= ENV['AWS_ACCOUNT_NUMBER']
      
      @global.cert ||= ENV['EC2_CERT']
      @global.privatekey ||= ENV['EC2_PRIVATE_KEY']
      
      @global.local_user = ENV['USER'] || :rudy
      @global.local_hostname = Socket.gethostname || :localhost
      
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
      
      String.disable_color if @global.nocolor
      Rudy.enable_quiet if @global.quiet
    end
    
    def debug?; @@debug && @@debug == true; end
    
    def check_keys
      raise "No EC2 .pem keys provided" unless has_pem_keys?
      raise "No SSH key provided for #{current_user}!" unless has_keypair?
      raise "No SSH key provided for root!" unless has_keypair?(:root)
    end
      
    def has_pem_keys?
      (@global.cert       && File.exists?(@global.cert) && 
       @global.privatekey && File.exists?(@global.privatekey))
    end
     
    def has_keys?
      (@global.accesskey && !@global.accesskey.empty? && @global.secretkey && !@global.secretkey.empty?)
    end
    
    
    def has_keypair?(name=nil)
      kp = user_keypairpath(name)
      (!kp.nil? && File.exists?(kp))
    end
    
    def user_keypairpath(name)
      raise "No default user configured" unless name
      kp = @config.machines.find(@global.environment, @global.role, :users, name, :keypair2)
      kp ||= @config.machines.find(@global.environment, :users, name, :keypair)
      kp ||= @config.machines.find(:users, name, :keypair)
      kp &&= File.expand_path(kp)
      kp
    end

    def current_user
      @global.user
    end
    def current_user_keypairpath
      user_keypairpath(current_user)
    end
    def current_machine_hostname(group=nil)
      group ||= machine_group
      find_machine(group)[:dns_name]
    end
    
    def current_machine_group
      [@global.environment, @global.role].join(RUDY_DELIM)
    end
    
    def current_machine_image
      ami = @config.machines.find_deferred(@global.environment, @global.role, :ami)
      raise "There is no AMI configured for #{current_machine_group}" unless ami
      ami
    end
    
    def current_machine_address
      @config.machines.find_deferred(@global.environment, @global.role, :address)
    end
    
    # TODO: fix machine_group to include zone
    def current_machine_name
      [@global.zone, current_machine_group, @global.position].join(RUDY_DELIM)
    end

    

    # +name+ the name of the remote user to use for the remainder of the command
    # (or until switched again). If no name is provided, the user will be revert
    # to whatever it was before the previous switch. 
    # TODO: deprecate
    def switch_user(name=nil)
      if name == nil && @switch_user_previous
        @global.user = @switch_user_previous
      elsif @global.user != name
        raise "No root keypair defined for #{name}!" unless has_keypair?(name)
        @logger.puts "Remote commands will be run as #{name} user"
        @switch_user_previous = @global.user
        @global.user = name
      end
    end
    
    # Returns a hash of info for the requested machine. If the requested machine
    # is not running, it will raise an exception. 
    def current_machine
      find_machine(current_machine_group)
    end
      
    def find_machine(group)
      machine_list = @ec2.instances.list(group)
      machine = machine_list.values.first  # NOTE: Only one machine per group, for now...
      raise "There's no machine running in #{group}" unless machine
      raise "The primary machine in #{group} is not in a running state" unless machine[:aws_state] == 'running'
      machine
    end
    

    
    def group_metadata(env=@global.environment, role=@global.role)
      query = "['environment' = '#{env}'] intersection ['role' = '#{role}']"
      @sdb.query_with_attributes(RUDY_DOMAIN, query)
    end
    
    # * +opts+
    # :recursive => false, :preserve => false, :chunk_size => 16384
    def scp(task, host, user, keypairpath, paths, dest, opts)
      opts = { 
        :recursive => false, :preserve => false, :chunk_size => 16384
      }.merge(opts)
      
      Net::SCP.start(host, @global.user, :keys => [keypairpath]) do |scp|
        paths.each do |path| 
          prev_path = nil
          scp.send("#{task}!", path, dest, opts) do |ch, name, sent, total|
            msg = ((prev_path == name) ? "\r" : "\n") # new line for new file
            msg << "#{name}: #{sent}/#{total}"  # otherwise, update the same line
            @logger.print msg
            @logger.flush        # update the screen every cycle
            prev_path = name
          end
          @logger.puts unless prev_path == path
        end
      end
    end
    
    
    
  private 
    
    
    def init_config_dir
      unless File.exists?(RUDY_CONFIG_DIR)
        puts "Creating #{RUDY_CONFIG_DIR}"
        Dir.mkdir(RUDY_CONFIG_DIR, 0700)
      end

      unless File.exists?(RUDY_CONFIG_FILE)
        puts "Creating #{RUDY_CONFIG_FILE}"
        rudy_config = Rudy::Utils.without_indent %Q{
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
        Rudy::Utils.write_to_file(RUDY_CONFIG_FILE, rudy_config, 'w')
      end

    end
  end
end