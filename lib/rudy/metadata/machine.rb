##--
## CONSIDER: http://docs.rackspacecloud.com/servers/api/v1.0/cs-devguide-20090713.pdf
##++

  
  
module Rudy
  class Machine < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :created => Time
    field :started => Time
    
    field :rtype => String
    field :instid => String

    field :region => Symbol
    field :zone => Symbol
    field :environment => Symbol
    field :role => Symbol
    field :position => Integer
    
    field :size => String
    field :ami => String
    field :group => String
    field :keypair => String
    field :address => String
    
    field :dns_public => String
    field :dns_private => String
    field :state => String
    
    field :os => Symbol
    field :impl => Symbol
    
    attr_reader :instance
    
      # An ephemeral value which is set after checking whether 
      # the SSH daemon is running. By default this will be set 
      # to false but can be set to true to avoid checking again.
      # See available?
    attr_writer :available
    
      # * +position+ 
      # * +opts+ is a hash of machine options.
      #
      # Valid options are:
      # * +:position+ (overridden by +position+ arg)
      # * +:size+ 
      # * +:os+
      # * +:ami+
      # * +:group+
      # * +:keypair+
      # * +:address+
      #
    def initialize(position='01', opts={})
      
      opts = {
        :size => current_machine_size,
        :os => current_machine_os,
        :ami => current_machine_image,
        :group => current_group_name,
        :keypair => root_keypairname
      }.merge opts
      
      opts[:address] = current_machine_address opts[:position] || position
      
      super Rudy::Machines::RTYPE, opts  # Rudy::Metadata#initialize
      
      @position = position
      
      # Defaults:
      @created = Time.now.utc
      @available = false
      postprocess
      
    end
    
    def postprocess
      @position &&= @position.to_s.rjust(2, '0')
      @os &&= @os.to_sym
    end
    
    def to_s(*args)
      [self.name.bright, self.instid, self.dns_public].join '; '
    end
    
    def rbox
      r = Rudy::Routines::Handlers::RyeTools.create_box self
    end
    
    def disks
      Rudy::Disks.list
    end
    
    
    def get_instance
      Rudy::AWS::EC2::Instances.get @instid
    end
    
    def get_console
      raise "Instance not running" unless instance_running?
      raw = Rudy::AWS::EC2::Instances.console @instid
      console = Base64.decode64(raw)
      # The linux console can include ANSI escape codes for color, 
      # clear screen etc... We strip them out to get rid of the 
      # clear specifically. Otherwise the display is messed!
      console &&= console.noansi if console.respond_to? :noansi
      console
    end
    
    def get_password
      unless windows?
        raise "Password support is Windows only (this is #{@os})" 
      end
      console = get_console
      
      raise "Console output not yet available. Please wait." if console.nil?
      
      unless console.match(/<Password>(.+)<\/Password>/m)  
        # /m, match multiple lines
        raise "Password not yet available. Is this a custom AMI?"
      end  
      
      encrtypted_text = ($1 || '').strip
      k = Rye::Key.from_file root_keypairpath
      k.decrypt encrtypted_text
    end
    
    def create_mock
      refresh!
      @dns_public = @dns_private = nil
      inst = Rudy::AWS::EC2::Instances.list(:running).first
      @instid = inst.awsid
      self.save :replace
      sleep 1
      self
    end
    
    def create
      raise "#{name} is already running" if instance_running?
      
      # Options for Rudy::AWS::EC2::Instances#create
      opts = {
        :min  => 1,
        :size => @size,
        :ami => @ami,
        :group => @group,
        :keypair => @keypair, 
        :zone => @zone,
        :machine_data => self.generate_machine_data.to_yaml
      }
      
      ld "OPTS: #{opts.inspect}"
      
      Rudy::AWS::EC2::Instances.create(opts) do |inst|
        @instid = inst.awsid
        @created = @started = Time.now
        @state = inst.state
        # We need to be safe when creating machines because if an exception is
        # raised, instances will have been created but the calling class won't know. 
      end
      
      self.save
      
      sleep 1 # Eventual consistency in SimpleDB
      
      self
    end
    
    def destroy
      Rudy::AWS::EC2::Instances.destroy(@instid) if instance_running?
      super
    end
    
    def restart
      Rudy::AWS::EC2::Instances.restart(@instid) if instance_running?
    end
    
    def attached_volumes
      volumes = []
      return volumes if @instid.nil?
      Rudy::AWS::EC2::Volumes.list_by_instance( @instid) || []
    end
    
    def refresh!(metadata=true)
      ## Updating the metadata isn't necessary
      super() if metadata # update metadata
      @instance = get_instance
      if @instance.is_a?(Rudy::AWS::EC2::Instance)
        @dns_public, @dns_private = @instance.dns_public, @instance.dns_private
        @state = @instance.state
        save :replace
      elsif @instance.nil?
        @awsid = @dns_public = @dns_private = nil
        @state = 'rogue'
        # Don't save it b/c it's possible the EC2 server is just down. 
      end
    end
    
    def generate_machine_data
      d = {}
      [:region, :zone, :environment, :role, :position].each do |k|
        d[k] = self.send k
      end
      d
    end
    
    def default_fstype
      windows? ? Rudy::DEFAULT_WINDOWS_FS : Rudy::DEFAULT_LINUX_FS
    end
    
    def default_device
      windows? ? Rudy::DEFAULT_WINDOWS_DEVICE : Rudy::DEFAULT_LINUX_DEVICE
    end
    
    
    def os?(v); @os.to_s == v.to_s; end
    def windows?; os? 'windows'; end
    def linux?; os? 'linux'; end
    def solaris?; os? 'solaris'; end
    
    def dns_public?;  !@dns_public.nil? && !@dns_public.empty?;   end
    def dns_private?; !@dns_private.nil? && !@dns_private.empty?; end
    
    # See +available+ attribute
    def available?; @available; end
    
    # Create instance_*? methods
    %w[exists? running? pending? terminated? shutting_down? unavailable?].each do |state|
      define_method("instance_#{state}") do
        return false if @instid.nil? || @instid.empty?
        Rudy::AWS::EC2::Instances.send(state, @instid) rescue false # exists?, running?, etc...
      end
    end
    
  end
end