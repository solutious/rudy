##--
## CONSIDER: http://docs.rackspacecloud.com/servers/api/v1.0/cs-devguide-20090713.pdf
##++

module Rudy
  class Machine < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :rtype
    field :instid

    field :region
    field :zone
    field :environment
    field :role
    field :position
    
    field :size
    field :ami
    field :group
    field :keypair
    field :address
    
    field :created => Time
    field :started => Time
    
    field :dns_public
    field :dns_private
    field :state
    
    field :os
    field :impl
    
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
      
      super 'm', opts  # Rudy::Metadata#initialize
      
      @position = position
      
      # Defaults:
      @created = Time.now.utc
      @available = false
      postprocess
      
    end
    
    def postprocess
      @position &&= @position.to_s.rjust(2, '0')
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
      
      Rudy::Huxtable.ld "OPTS: #{opts.inspect}"
      
      @@rinst.create(opts) do |inst|
        @instid = inst.instid
        @created = @started = Time.now
        @state = inst.state
        # We need to be safe when creating machines because if an exception is
        # raised, instances will have been created but the calling class won't know. 
        begin
          # Assign IP address only if we have one for that position
          if @address
            # Make sure the address is associated to the current account
            if @@radd.exists?(@address)
              puts "Associating #{@address} to #{@instid}"
              @@radd.associate(@address, @instid)
            else
              STDERR.puts "Unknown address: #{@address}"
            end
          end
        rescue => ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts ex.backtrace if Rudy.debug?
        end
      end
      self.save
      self
    end
    
    def destroy
      @@rinst.destroy(@instid) if instance_running?
      super
    end
    
    def restart
      @@rinst.restart(@instid) if instance_running?
    end
    
    def generate_machine_data
      d = {}
      [:region, :zone, :environment, :role, :position].each do |k|
        d[k] = self.send k
      end
      d
    end
    
    def dns_public?;  !@dns_public.nil? && !@dns_public.empty?;   end
    def dns_private?; !@dns_private.nil? && !@dns_private.empty?; end
    
    # See +available+ attribute
    def available?; @available; end
    
    # Create instance_*? methods
    %w[exists? running? pending? terminated? shutting_down? unavailable?].each do |state|
      define_method("instance_#{state}") do
        return false if @instid.nil? || @instid.empty?
        @@rinst.send(state, @instid) rescue false # exists?, running?, etc...
      end
    end
    
  end
end