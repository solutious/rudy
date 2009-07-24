

module Rudy
  class Disk < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :rtype
    field :volid
    field :status
    field :instid

    field :path

    field :device
    field :size
    field :fstype
    
    #field :backups => Array
    
    # Is the associated volume formatted? One of: true, false, [empty]. 
    # [empty] means we don't know and it's the default. 
    field :raw
    field :mounted
    field :created  => Time
    
    # * +path+ is a an absolute filesystem path
    # * +opts+ is a hash of disk options.
    #
    # Valid options are:
    # * +:path+ is a an absolute filesystem path (overridden by +path+ arg)
    # * +:size+ 
    # * +:device+
    # * +:position+
    #
    def initialize(path=nil, opts={})
      
      opts = {
        :size => 1,
        :device => '/dev/sdh'
      }.merge opts
      
      super 'disk', opts  # Rudy::Metadata#initialize
      
      @path = path
      
      # Defaults:
      #datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = Time.now.utc
      @mounted = false
      postprocess
      
    end
    
    # sdb values are stored as strings. Some quick conversion. 
    def postprocess
      @size &&= @size.to_i
      @mounted = (@mounted == "true") unless @mounted.is_a?(TrueClass)
    end
    
    def to_s(with_titles=true)
      "%s; %s" % [self.name, self.to_hash.inspect]
    end
    
    def name
      sep = File::SEPARATOR
      if Rudy.sysinfo.os == :unix
        dirs = @path.split sep if @path && !@path.empty?
        unless @path == File::SEPARATOR
          dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        end
        super *dirs  # Calls Rudy::Metadata.name with disk specific components
      else
        raise UnsupportedOS, "Disks are not available for #{Rudy.sysinfo.os}"
      end
    end
    
    def create(size=nil, zone=nil, snapshot=nil)
      raise "#{self.name} already exists" if exists?
      vol = Rudy::AWS::EC2::Volumes.create(size || @size, zone || @zone, snapshot) 
      #vol = Rudy::AWS::EC2::Volumes.list(:available).first   # debugging
      @volid, @raw = vol.awsid, true
      self.save
      self
    end
    
    def destroy(force=false)
      if @volid && !volume_deleting?
        if !force
          raise Rudy::AWS::EC2::VolumeNotAvailable, @volid if volume_attached?
        else
          volume_detach if volume_exists? && volume_attached?
          sleep 0.1
        end
        raise Rudy::AWS::EC2::VolumeNotAvailable, @volid if volume_in_use?
        Rudy::AWS::EC2::Volumes.destroy(@volid) if volume_exists? && volume_available?
      end
      super() # quotes, otherwise Ruby will send this method's args
    end
    
    def valid?
      !@path.nil? && !@path.empty?
    end
    
    
    def volume_attach(instid)
      raise Rudy::Error, "No volume id" unless volume_exists?
      vol = @rvol.attach(@volid, instid, @device)
    end

    def volume_detach
      raise Rudy::Error, "No volume id" unless volume_exists?
      vol = @rvol.detach(@volid)
    end


    # Create volume_*? methods
    %w[exists? deleting? available? attached? in_use?].each do |state|
      define_method("volume_#{state}") do
        return false if @volid.nil? || @volid.empty?
        Rudy::AWS::EC2::Volumes.send(state, @volid) rescue false # deleting?, available?, etc...
      end
    end
    
  end
end