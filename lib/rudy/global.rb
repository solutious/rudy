

module Rudy
  
  # = Rudy::Global
  #
  # This global class is used by all Huxtable objects.
  # When a new CLI global is added, the appropriate field must
  # be added to this class (optional: a default value in initialize).
  class Global < Storable
    
    field :config => String
    field :region
    field :zone
    field :environment
    field :role
    field :position
    field :user
    field :pkey
    
    field :debug
    field :nocolor
    field :quiet
    field :verbose
    field :format
    field :print_header
    field :auto
    field :force
    
    field :accesskey
    field :secretkey
    field :accountnum
    field :accountname  # TODO: use this. And accounttype (aws)
    field :cert
    field :pkey
    
    field :localhost
    field :parallel
    field :identity
    
    field :testrun
    field :offline
    field :bucket

    field :positions
    
    
    attr_accessor :print_header
    
    def initialize
      postprocess
      # These attributes MUST have values. 
      @verbose ||= 0
      @nocolor = true unless @nocolor == "false" || @nocolor == false
      @quiet ||= false
      @parallel ||= false
      @force ||= false
      @format ||= :string # as in, to_s
      @print_header = true if @print_header == nil
    end
    
    def apply_config(config)

      return unless config.is_a?(Rudy::Config)
      clear_system_defaults  # temporarily unapply default values
      
      if config.defaults?
        # Apply the "color" default before "nocolor" so nocolor has presedence
        @nocolor = !config.defaults.color unless config.defaults.color.nil?
        # WARNING: Don't add user to this list. The global value should return
        # the value specified on the command line or nil. If it is nil, we can
        # check the value from the machines config. If that is nil, we use the
        # value from the defaults config. 
        # WARNING: Don't add bucket either or any machines configuration param 
        # TODO: investigate removing this apply_config method
        %w[region zone environment role position bucket
           localhost nocolor quiet auto force parallel].each do |name|
          curval, defval = self.send(name), config.defaults.send(name)
          if curval.nil? && !defval.nil?
            # Don't use the accessors. These are defaults so no Region  magic. 
            self.instance_variable_set("@#{name}", defval) 
          end
        end
      end
      
      if config.accounts? && config.accounts.aws
        %w[accesskey secretkey accountnum cert pkey].each do |name|
          val = config.accounts.aws.send(name)
          self.send("#{name}=", val) unless val.nil?
        end
      end
      postprocess
    end
    
    def update(ghash={})
      ghash = ghash.marshal_dump if ghash.is_a?(OpenStruct) 
      ghash.each_pair { |n,v| self.send("#{n}=", v) } 
      postprocess
    end
    
    def zone=(z)
      @zone = z
      @region = @zone.to_s.gsub(/[a-z]$/, '').to_sym
    end
    
    def region=(r)
      @region = r
      @zone = "#{@region}b".to_sym
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
      @pkey &&= File.expand_path(@pkey)
      @position &&= @position.to_s.rjust(2, '0')  
      @format &&= @format.to_sym rescue nil
      @quiet ? Rudy.enable_quiet : Rudy.disable_quiet
      @auto ? Rudy.enable_auto : Rudy.disable_auto
      
    end
    
    def apply_environment_variables
      @accesskey ||= ENV['AWS_ACCESS_KEY']
      @secretkey ||= ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
      @accountnum ||= ENV['AWS_ACCOUNT_NUMBER']
      @cert ||= ENV['EC2_CERT']
      @pkey ||= ENV['EC2_PRIVATE_KEY']
    end
    
    # Apply defaults for parameters that must have values
    def apply_system_defaults
      if    @region.nil? && @zone.nil?
        @region, @zone = Rudy::DEFAULT_REGION, Rudy::DEFAULT_ZONE
      elsif @region.nil?
        @region = @zone.to_s.gsub(/[a-z]$/, '').to_sym
      elsif @zone.nil?
        @zone = "#{@region}b".to_sym
      end
      
      @environment ||= Rudy::DEFAULT_ENVIRONMENT
      @role ||= Rudy::DEFAULT_ROLE
      @localhost ||= Rudy.sysinfo.hostname || 'localhost'
      @auto = false if @auto.nil?
    end
    
    # Unapply defaults for parameters that must have values. 
    # This is important when reloading configuration since
    # we don't overwrite existing values. If the default
    # ones remained the configuration would not be applied.
    def clear_system_defaults
      @region = nil if @region == Rudy::DEFAULT_REGION
      @zone = nil if @zone == Rudy::DEFAULT_ZONE
      @environment = nil if @environment == Rudy::DEFAULT_ENVIRONMENT
      @role = nil if @role == Rudy::DEFAULT_ROLE
      @localhost = nil if @localhost == (Rudy.sysinfo.hostname || 'localhost')
      @auto = nil if @auto == false
    end
    
  end
end
