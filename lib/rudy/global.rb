

module Rudy
  class Global < Storable
    
    field :region
    field :zone
    field :environment
    field :role
    field :position
    field :user
    
    field :nocolor
    field :quiet
    field :verbose
    
    field :accesskey
    field :secretkey
    field :accountnum
    field :accountname  # TODO: use this. And accounttype (aws)
    field :cert
    field :privatekey
    
    field :local_user
    field :local_hostname
    
    field :config => String
    
    def initialize
      postprocess
      @verbose ||= 0
      @nocolor ||= false
      @quiet ||= false
    end
      
    def apply_config(config)
      return unless config.is_a?(Rudy::Config)
      if config.defaults?
        %w[region zone environment role position user nocolor quiet].each do |name|
          val = config.defaults.send(name)
          self.send("#{name}=", val) if val
        end
      end
      
      if config.accounts? && config.accounts.aws
        %w[accesskey secretkey accountnum cert privatekey].each do |name|
          val = config.accounts.aws.send(name)
          self.send("#{name}=", val) if val
        end
      end
      
      postprocess
    end
    
    
    def update(ghash={})
      ghash = ghash.marshal_dump if ghash.is_a?(OpenStruct)
      
      if ghash.is_a?(Hash)
        ghash.each_pair { |n,v| self.send("#{n}=", v) } 
      else
        raise "Unexpected #{ghash.class.to_s}"
      end
      
      postprocess
    end
    
    
  private 
    
    
    def postprocess
      apply_environment_variables
      apply_system_defaults

      @cert &&= File.expand_path(@cert)
      @privatekey &&= File.expand_path(@privatekey)
      @position &&= @position.to_s.rjust(2, '0')  
      
      String.disable_color if @nocolor
      Rudy.enable_quiet if @quiet
    end
    
    def apply_environment_variables
      @accesskey ||= ENV['AWS_ACCESS_KEY']
      @secretkey ||= ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
      @accountnum ||= ENV['AWS_ACCOUNT_NUMBER']
      @cert ||= ENV['EC2_CERT']
      @privatekey ||= ENV['EC2_PRIVATE_KEY']
      @local_user = ENV['USER'] || :rudy
      @local_hostname = Socket.gethostname || :localhost  
    end
    
    def apply_system_defaults
      @region ||= Rudy::DEFAULT_REGION
      @zone ||= Rudy::DEFAULT_ZONE
      @environment ||= Rudy::DEFAULT_ENVIRONMENT
      @role ||= Rudy::DEFAULT_ROLE
      @position ||= Rudy::DEFAULT_POSITION
      @user ||= Rudy::DEFAULT_USER
    end
    
  end
end
