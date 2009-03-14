


module Rudy
  module Huxtable
    attr_accessor :config
    attr_accessor :global
    attr_accessor :logger
    
    def initialize(opts={})
      opts = { :config => {}, :logger => STDERR, :global => {}}.merge(opts)
      
      # Set instance variables
      opts.each_pair { |n,v| self.send("#{n}=", v) if self.respond_to?("#{n}=") }
      
      if has_keys?
        @ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
        @sdb = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
        #@s3 = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
      end
      
      @script_runner = Rudy::Routines::ScriptRunner.new(opts)
      #@disks = Rudy::Routines::Disks.new()
    end
    
    def check_keys
      raise "No EC2 .pem keys provided" unless has_pem_keys?
      raise "No SSH key provided for #{@global.user}!" unless has_keypair?
      raise "No SSH key provided for root!" unless has_keypair?(:root)
    end
      
    def has_pem_keys?
      (@global.cert       && File.exists?(@global.cert) && 
       @global.privatekey && File.exists?(@global.privatekey))
    end
     
    def has_keys?
      (@global.accesskey && !@global.accesskey.empty? && @global.secretkey && !@global.secretkey.empty?)
    end
    
    def keypairpath(name=nil)
      name ||= @global.user
      raise "No default user configured" unless name
      kp = @config.machines.find(@global.environment, @global.role, :users, name, :keypair2)
      kp ||= @config.machines.find(@global.environment, :users, name, :keypair)
      kp ||= @config.machines.find(:users, name, :keypair)
      kp &&= File.expand_path(kp)
      kp
    end
    def has_keypair?(name=nil)
      kp = keypairpath(name)
      (!kp.nil? && File.exists?(kp))
    end
    
    
    
    

    # +name+ the name of the remote user to use for the remainder of the command
    # (or until switched again). If no name is provided, the user will be revert
    # to whatever it was before the previous switch. 
    def switch_user(name=nil)
      if name == nil && @switch_user_previous
        @global.user = @switch_user_previous
      elsif @global.user != name
        puts "Remote commands will be run as #{name} user"
        @switch_user_previous = @global.user
        @global.user = name
      end
    end
    
    # Returns a hash of info for the requested machine. If the requested machine
    # is not running, it will raise an exception. 
    def find_current_machine
      find_machine(machine_group)
    end
      
    def find_machine(group)
      machine_list = @ec2.instances.list(group)
      machine = machine_list.values.first  # NOTE: Only one machine per group, for now...
      raise "There's no machine running in #{group}" unless machine
      raise "The primary machine in #{group} is not in a running state" unless machine[:aws_state] == 'running'
      machine
    end
    
    def machine_hostname(group=nil)
      group ||= machine_group
      find_machine(group)[:dns_name]
    end
    
    def machine_group
      [@global.environment, @global.role].join(RUDY_DELIM)
    end
    
    def machine_image
      ami = @config.machines.find_deferred(@global.environment, @global.role, :ami)
      raise "There is no AMI configured for #{machine_group}" unless ami
      ami
    end
    
    def machine_address
      @config.machines.find_deferred(@global.environment, @global.role, :address)
    end
    
    # TODO: fix machine_group to include zone
    def machine_name
      [@global.zone, machine_group, @global.position].join(RUDY_DELIM)
    end


    
    def wait_for_machine(id)
      
      print "Waiting for #{id} to become available"
      STDOUT.flush
      
      while @ec2.instances.pending?(id)
        sleep 2
        print '.'
        STDOUT.flush
      end
      
      machine = @ec2.instances.get(id)
      
      puts " It's up!\a\a" # with bells
      print "Waiting for SSH daemon at #{machine[:dns_name]}"
      STDOUT.flush
      
      while !Rudy::Utils.service_available?(machine[:dns_name], 22)
        print '.'
        STDOUT.flush
      end
      puts " It's up!\a\a\a"

    end
    

    
    def group_metadata(env=@global.environment, role=@global.role)
      query = "['environment' = '#{env}'] intersection ['role' = '#{role}']"
      @sdb.query_with_attributes(RUDY_DOMAIN, query)
    end
    
    
  end
end