

module Rudy
  
  # = Rudy::Global
  #
  # This global class is used by all Huxtable objects.
  # When a new CLI global is added, the appropriate field must
  # be added to this class (optional: a default value in initialize).
  class Global < Storable
    
    field :region
    field :zone
    field :environment
    field :role
    field :position
    field :user
    field :pkey
    
    field :nocolor
    field :quiet
    field :verbose
    field :format
    field :print_header
    field :yes
    
    field :accesskey
    field :secretkey
    field :accountnum
    field :accountname  # TODO: use this. And accounttype (aws)
    field :cert
    field :privatekey
    
    field :testrun
    
    field :user
    field :localhost
    
    field :parallel
    
    field :offline
    
    field :config => String
    
    attr_accessor :print_header
    
    def initialize
      postprocess
      # These attributes MUST have values. 
      @verbose ||= 0
      @nocolor = true unless @nocolor == "false" || @nocolor == false
      @quiet ||= false
      @parallel ||= false
      @format ||= :string # as in, to_s
      @print_header = true if @print_header == nil
      @yes = false if @yes.nil?
    end
    
    def apply_config(config)
      return unless config.is_a?(Rudy::Config)
      if config.defaults?
        # Apply the "color" default before "nocolor" so nocolor has presedence
        @nocolor = !config.defaults.color unless config.defaults.color.nil?
        %w[region zone environment role position user 
           localhost nocolor quiet yes parallel].each do |name|
          val = config.defaults.send(name)
          self.send("#{name}=", val) unless val.nil?
        end
      end
      
      if config.accounts? && config.accounts.aws
        %w[accesskey secretkey accountnum cert privatekey].each do |name|
          val = config.accounts.aws.send(name)
          self.send("#{name}=", val) unless val.nil?
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
    
    def to_s(*args)
      super()
    end
      
  private 
    
    
    def postprocess
      apply_environment_variables
      apply_system_defaults
      @nocolor = !@color unless @color.nil?
      @cert &&= File.expand_path(@cert)
      @privatekey &&= File.expand_path(@privatekey)
      @position &&= @position.to_s.rjust(2, '0')  
      @format &&= @format.to_sym rescue nil
      @quiet ? Rudy.enable_quiet : Rudy.disable_quiet
      @yes ? Rudy.enable_yes : Rudy.disable_yes
    end
    
    def apply_environment_variables
      @accesskey ||= ENV['AWS_ACCESS_KEY']
      @secretkey ||= ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
      @accountnum ||= ENV['AWS_ACCOUNT_NUMBER']
      @cert ||= ENV['EC2_CERT']
      @privatekey ||= ENV['EC2_PRIVATE_KEY']
      @user = ENV['USER'] 
    end
    
    def apply_system_defaults
      @region ||= Rudy::DEFAULT_REGION
      @zone ||= Rudy::DEFAULT_ZONE
      @environment ||= Rudy::DEFAULT_ENVIRONMENT
      @role ||= Rudy::DEFAULT_ROLE
      @position ||= Rudy::DEFAULT_POSITION
      @user ||= Rudy.sysinfo.user || 'rudy'
      @localhost ||= Rudy.sysinfo.hostname || 'localhost'
    end
    
  end
end
