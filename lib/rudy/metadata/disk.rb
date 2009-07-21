

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
    field :created
    
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
      super 'disk'  # Calls Rudy::Metadata#initialize with rtype
      
      opts = {
        :size => 1,
        :device => '/dev/sdh',
        :position => '01'
      }.merge opts
      
      opts.each_pair do |n,v|
        raise "Unknown attribute for #{self.class}: #{n}" if !self.has_field? n
        self.send("#{n}=", v)
      end
      @path = path
      
      # Defaults:
      now = Time.now.utc
      #datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = now.to_i
      @mounted = false
      postprocess
      
    end
    
    # sdb values are stored as strings. Some quick conversion. 
    def postprocess
      @size &&= @size.to_i
      @mounted = (@mounted == "true") unless @mounted.is_a?(TrueClass)
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
      #vol = @@rvol.create(size || @size, zone || @zone, snapshot) 
      vol = @@rvol.list.first
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
        @@rvol.destroy(@volid) if volume_exists? && volume_available?
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
        @@rvol.send(state, @volid) rescue false # deleting?, available?, etc...
      end
    end
    
    
    # ----------------------------------------  CLASS METHODS  -----
    def self.get(path)
      tmp = Rudy::Disk.new path
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
  end
end