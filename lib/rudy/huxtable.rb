


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
    
    
  end
end