

module Rudy
  class Disk < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :created  => Time
    field :rtype => String
    field :volid => String
    field :status => String
    field :instid => String

    field :path => String

    field :device => String
    field :size => String
    field :fstype => String
    
    field :name     => String# Windows, used for label
    field :index    => String# Windows, used for diskpart
    
    #field :backups => Array
    
    # Is the associated volume formatted? One of: true, false
    field :raw => String
    field :mounted => String
    
    # If one argument is supplied:
    # * +path+ is a an absolute filesystem path
    # * +opts+ is a hash of disk options.
    #
    # If two arguments are supplied:
    # * +position+ 
    # * +path+ is a an absolute filesystem path
    # * +opts+ is a hash of disk options.
    #
    # Valid options are:
    # * +:path+ is a an absolute filesystem path (overridden by +path+ arg)
    # * +:position+ (overridden by +position+ arg)
    # * +:size+ 
    # * +:device+
    #
    def initialize(position=nil, path=nil, opts={})
      # Swap arg values if only one is supplied. 
      path, position = position, nil if !position.nil? && path.nil?
      position ||= '01'
      
      opts = {
        :size => 1,
        :device => current_machine_os.to_s == 'windows' ? DEFAULT_WINDOWS_DEVICE : DEFAULT_LINUX_DEVICE
      }.merge opts
      
      super Rudy::Disks::RTYPE, opts  # Rudy::Metadata#initialize
      
      @position, @path = position, path
      
      # Defaults:
      #datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = Time.now.utc
      @mounted = false
      postprocess

    end
    
    # sdb values are stored as strings. Some quick conversion. 
    def postprocess
      @position = @position.to_s.rjust(2, '0') if @position.to_s.size == 1
      @size &&= @size.to_i
      @raw = true if @raw == "true" unless @raw.is_a?(TrueClass)
      @mounted = (@mounted == "true") unless @mounted.is_a?(TrueClass)
    end
    
    def to_s(*args)
      [self.name.bright, self.volid, self.size, self.fstype].join '; '
    end
    
    def name
      sep = File::SEPARATOR
      dirs = @path.split sep if @path && !@path.empty?
      unless @path == File::SEPARATOR
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
      end
      # Calls Rudy::Metadata#name with disk specific components
      super *dirs  
    end
    
    def create(size=nil, zone=nil, snapshot=nil)
      raise DuplicateRecord, self.name if exists? && !@@global.force
      vol = Rudy::AWS::EC2::Volumes.create(size || @size, zone || @zone, snapshot) 
      #vol = Rudy::AWS::EC2::Volumes.list(:available).first   # debugging
      @volid, @raw = vol.awsid, true
      self.save :replace
      self
    end
    
    def archive
      raise Rudy::AWS::EC2::VolumeNotAvailable, @volid unless volume_attached?
      back = Rudy::Backup.new @position, @path, self.descriptors
      back.create
      back.size, back.fstype = @size, @fstype
      back.save :replace
      back
    end
    
    def backups
      Rudy::Backups.list self.descriptors
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
    
    def descriptors
      super :position, :path
    end
    
    
    
    def valid?
      !@path.nil? && !@path.empty?
    end
    
    
    def volume_attach(instid)
      raise Rudy::Error, "No volume id" unless volume_exists?
      vol = Rudy::AWS::EC2::Volumes.attach(@volid, instid, @device)
    end

    def volume_detach
      raise Rudy::Error, "No volume id" unless volume_exists?
      vol = Rudy::AWS::EC2::Volumes.detach(@volid)
    end
    
    def raw?
      @raw == true
    end
    
    def mounted?
      @mounted == true
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