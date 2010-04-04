
require 'date'
    
module Rudy
  class Backup < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :created => Time
    field :rtype => String
    field :snapid => String
    field :volid => String
    
    field :path => String
    
    field :year => String
    field :month => String
    field :day => String
    field :hour => String
    field :minute => String
    field :second => String
    
    field :user => String
    field :size => String
    field :fstype => String
    
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
    # * +:created+ is an instance of Time
    # * +:user+ is the name of the user which created the backup. 
    #
    def initialize(position=nil, path=nil, opts={})
      # Swap arg values if only one is supplied. 
      path, position = position, nil if !position.nil? && path.nil?
      position ||= '01'
      
      opts = {
        :created => Time.now.utc,
        :user => Rudy.sysinfo.user
      }.merge opts
      
      super Rudy::Backups::RTYPE, opts  # Rudy::Metadata#initialize
      
      @position, @path = position, path
      
      postprocess

    end
    
    def postprocess
      @position &&= @position.to_s.rjust(2, '0')
      @year = @created.year
      @month = @created.month.to_s.rjust(2, '0')
      @day = @created.mday.to_s.rjust(2, '0')
      @hour = @created.hour.to_s.rjust(2, '0')
      @minute = @created.min.to_s.rjust(2, '0')
      @second = @created.sec.to_s.rjust(2, '0')
    end
    
    def to_s(*args)
      [self.name.bright, self.snapid, self.volid, self.size, self.fstype].join '; '
    end
    
    def name
      sep = File::SEPARATOR
      dirs = @path.split sep if @path && !@path.empty?
      unless @path == File::SEPARATOR
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
      end
      # Calls Rudy::Metadata#name with backup specific components
      super [dirs, date, time, second]
    end
    
    def date
      "%s%s%s" % [@year, @month, @day]
    end
    
    def time
      "%s%s" % [@hour, @minute]
    end
    
    def create
      raise DuplicateRecord, self.name if exists?
      disk = self.disk
      ld "DISK: #{disk.name}"
      raise Rudy::Backups::NoDisk, disk.name unless disk.exists?
      @volid ||= disk.volid
      snap = Rudy::AWS::EC2::Snapshots.create(@volid) 
      #snap = Rudy::AWS::EC2::Snapshots.list.first   # debugging
      ld "SNAP: #{snap.inspect}"
      @snapid, @raw = snap.awsid, true
      @size, @fstype = disk.size, disk.fstype
      self.save :replace
      self
    end
    
    def restore
      raise UnknownObject, self.name unless exists?
      raise Rudy::Backups::NoBackup, self.name unless any?
      
    end
    
    # Are there any backups for the associated disk?
    def any?
      backups = Rudy::Backups.list self.descriptors, [:year, :month, :day, :hour, :second]
      !backups.nil?
    end
    
    def descriptors
      super :position, :path, :year, :month, :day, :hour, :second
    end
    
    def destroy 
      Rudy::AWS::EC2::Snapshots.destroy(@snapid) if snapshot_exists?
      super()
    end
    
    def valid?
      !@path.nil? && !@path.empty? && @created.is_a?(Time) && !@volid.nil?
    end
    
    def disk
      opts = {
        :region => @region,  :zone => @zone,
        :environment => @environment, :role => @role, 
        :size => @size, :fstype => @fstype
      }
      disk = Rudy::Disk.new @position, @path, opts
      disk.refresh! if disk.exists?
      disk.size = @size
      disk.fstype = @fstype
      disk
    end
    
    def disk_exists?
      self.disk.exists?
    end
    
    # Create snapshot_*? methods
    %w[exists? completed?].each do |state|
      define_method("snapshot_#{state}") do
        return false if @snapid.nil? || @snapid.empty?
        Rudy::AWS::EC2::Snapshots.send(state, @snapid) 
      end
    end
    
  end
end