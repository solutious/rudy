

module Rudy
class Disk < Storable
  include Rudy::MetaData::ObjectBase
  
  field :rtype
  field :awsid
  field :status
  field :instid
  
  field :region
  field :zone
  field :environment
  field :role
  field :position
  field :path
  
  field :device
  field :size
  #field :backups => Array
  
  field :mounted
  
  def init(path=nil, size=nil, device=nil, position=nil)
    @path, @size, @device = path, size, device
    @rtype = 'disk'
    @region = @@global.region
    @zone = @@global.zone
    @environment = @@global.environment
    @role = @@global.role
    @position = position || @@global.position
    @mounted = false
    postprocess
  end
  
  def postprocess
    @size &&= @size.to_i
    @mounted = true if @mounted == "true"
  end
  
  def liner_note
    info = @awsid && !@awsid.empty? ? @awsid : 'no volume'
    "%s  %s" % [self.name.bright, info]
  end
  
  def to_s(with_titles=true)
    update
    puts "FUCK" if @mounted
    mtd = @mounted == true ? "mounted" : @status
    "%s; %3sGB; %s; %s" % [liner_note, @size, @device, mtd]
  end
  
  def inspect
    lines = []
    lines << liner_note
    field_names.each do |key|
      next unless self.respond_to?(key)
      val = self.send(key)
      lines << sprintf(" %22s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
    end
    lines.join($/)
  end
  
  def name
    sep=File::SEPARATOR
    dirs = @path.split sep if @path && !@path.empty?
    dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
    super("disk", @zone, @environment, @role, @position, *dirs)
  end
  

  
  def create(snapshot=nil)
    raise "#{name} is already running" if exists?
    vol = @rvol.create(@size, @zone, snapshot) 
    @awsid = vol.awsid
    self.save
    self
  end
  
  def attach(instid)
    raise "No volume id" unless exists?
    vol = @rvol.attach(@awsid, instid, @device)
  end
  
  def detach
    raise "No volume id" unless exists?
    vol = @rvol.detach(@awsid)
  end
  
  def destroy(force=false)
    if @awsid && !deleting?
      if !force
        raise Rudy::AWS::EC2::VolumeNotAvailable, @awsid if attached?
      else
        detach if exists? && attached?
        sleep 0.1
      end
      raise Rudy::AWS::EC2::VolumeNotAvailable, @awsid if in_use?
      @rvol.destroy(@awsid) if exists? && available?
    end
    super() # quotes, otherwise Ruby will send this method's args
  end
  
  def update
    @awsid = nil if @awsid && @awsid.empty?
    @volume = @rvol.get(@awsid) if @awsid
    if @volume.is_a?(Rudy::AWS::EC2::Volume)
      @status = @volume.status
      @instid = @volume.instid
    else
      @awsid, @status, @instid = nil, nil, nil
      @mounted = false # I don't like having to set this
    end
    save
  end
  
  def to_query(more=[], less=[])
    super([:path, *more], less)  # Add path to the default fields
  end
  
  def to_select(more=[], less=[])
    super([:path, *more], less) 
  end
  
  # Does this disk have enough info to be saved or used?
  # The test is based on the same criteria for building
  # SimpleDB queries. 
  def valid?
    criteria = build_criteria([:path]).flatten
    criteria.size == criteria.compact.size
  end
  
  def mounted?
    @mounted && @mounted == true
  end
  
  
  %w[exists? deleting? available? attached? in_use?].each do |state|
    define_method(state) do
      return false if @awsid.nil? || @awsid.empty?
      @rvol.send(state, @awsid) rescue false # deleting?, available?, etc...
    end
  end
end

class Disks
  include Rudy::MetaData
  
    
  def create(&each_mach)
    
  end


  def destroy(&each_mach)
    #raise MachineGroupNotRunning, current_machine_group unless running?
    #raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
    list do |disk|
      puts "Destroying #{disk.name}"
      disk.destroy
    end
  end

  def list(more=[], less=[], &each_disk)
    disks = list_as_hash(&each_disk)
    disks &&= disks.values
    disks
  end

  def list_as_hash(more=[], less=[], &each_disk)
    query = to_select([:rtype, 'disk'], less)
    list = @sdb.select(query) || {}
    disks = {}
    list.each_pair do |n,d|
      disks[n] = Rudy::Disk.from_hash(d)
    end
    disks.each_pair { |n,disk| each_disk.call(disk) } if each_disk
    disks = nil if disks.empty?
    disks
  end

  def get(rname=nil)
    dhash = @sdb.get(Rudy::DOMAIN, rname)
    return nil if dhash.nil? || dhash.empty?
    d = Rudy::Disk.from_hash(dhash)
    d.update if d
    d
  end


  def running?
    !list.nil?
    # TODO: add logic that checks whether the instances are running.
  end


    
  
end
end

