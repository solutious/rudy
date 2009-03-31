


module Rudy
  module Huxtable
    include Rudy::AWS
    
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
      
      if has_keys?
        Rudy::AWS.set_access_identifiers(@global.accesskey, @global.secretkey, @logger)
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
      raise "No user provided" unless name
      zon, env, rol = @global.zone, @global.environment, @global.role
      #Caesars.enable_debug
      kp = @config.machines.find_deferred(zon, env, rol, [:users, name, :keypair])
      kp ||= @config.machines.find_deferred(env, rol, [:users, name, :keypair])
      kp ||= @config.machines.find_deferred(rol, [:users, name, :keypair])
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
    
  end
end