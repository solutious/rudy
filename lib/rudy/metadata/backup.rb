
require 'date'
    
module Rudy
  class Backup < Storable 
    include Rudy::Metadata
    include Gibbler::Complex
    
    field :rtype
    field :snapid
    field :volid
    
    field :path
    
    field :created => Time
    
    field :user
    field :size
    field :fstype
    
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
    end
    
    def to_s(with_titles=true)
      "%s; %s" % [self.name, self.to_hash.inspect]
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
    
    def create
      disk = self.disk
      raise DuplicateRecord, self.name if exists?
      raise Rudy::Backups::NoDisk, disk.name unless disk.exists?
      @volid ||= disk.volid
      snap = Rudy::AWS::EC2::Snapshot.create(@volid) 
      #snap = Rudy::AWS::EC2::Snapshots.list.first   # debugging
      @snapid, @raw = snap.awsid, true
      self.save
      self
    end
    
    def valid?
      !@path.nil? && !@path.empty? && @created.is_a?(Time) && !@volid.nil?
    end
    
    def date;    @created.strftime '%Y%m%d'; end
    def time;    @created.strftime '%H%M';   end
    def second;  @created.strftime '%S';     end
    
    def disk
      opts = {
        :region => @region,  :zone => @zone,
        :environment => @environment, :role => @role
      }
      disk = Rudy::Disk.new @position, @path, opts
      disk.refresh! if disk.exists?
      disk
    end
    
    def disk_exists?
      self.disk.exists?
    end
    
    # Create snapshot_*? methods
    %w[exists? completed?].each do |state|
      define_method("snapshot_#{state}") do
        return false if @snapid.nil? || @snapid.empty?
        Rudy::AWS::EC2::Snapshots.send(state, @snapid) rescue false
      end
    end
    
  end
end