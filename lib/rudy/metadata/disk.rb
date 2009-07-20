

module Rudy
  class Disk < Storable 
    include Rudy::Metadata
    
    field :rtype
    field :awsid
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

    # * +path+ is a an absolute filesystem path (required)
    # * +opts+ is a hash of disk options.
    #
    # Valid options are:
    # * +:size+ 
    # * +:device+
    # * +:position+
    #
    def initialize(path, opts={})
      super 'disk'  # Calls Rudy::Metadata#initialize with rtype
      opts = {
        :size => 1,
        :device => '/dev/sdh',
        :position => '01'
      }.merge opts
      
      @path = path
      opts.each_pair do |n,v|
        raise "Unknown attribute for #{self.class}: #{n}" if !self.has_field? n
        self.send("#{n}=", v)
      end
      
      # Defaults:
      now = Time.now.utc
      #datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = now.to_i
      @mounted = false
      postprocess
    end
    
    def valid?
      !@path.nil? && !@path.empty?
    end
    
    def postprocess
      # sdb values are stored as strings. Some quick conversion. 
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
    
    def self.get(path)
      Rudy::Huxtable.ld :path, path
      tmp = Rudy::Disk.new path
      record = Rudy::Metadata.get tmp.name
      Rudy::Huxtable.ld [:record, record.is_a?(Hash)]
      return nil unless record.is_a?(Hash)
      d = Rudy::Disk.new path
      d.from_hash record
    end
        
  end
end