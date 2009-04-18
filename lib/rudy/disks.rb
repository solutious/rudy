

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
    mtd = @mounted ? "mounted" : @status
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
        detach if attached?
        sleep 0.1
      end
      raise Rudy::AWS::EC2::VolumeNotAvailable, @awsid if in_use?
      @rvol.destroy(@awsid)
    end
    super() # quotes, otherwise Ruby will send this method's args
  end
  
  def update
    return false unless @awsid
    @volume = @rvol.get(@awsid) 
    if @volume.is_a?(Rudy::AWS::EC2::Volume)
      @status = @volume.status
      @instid = @volume.instid
      save
    end
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
    d = Rudy::Disk.from_hash(@sdb.get(Rudy::DOMAIN, rname)) # Returns nil if empty
    d.update
    d
  end


  def running?
    !list.nil?
    # TODO: add logic that checks whether the instances are running.
  end


    
  
end
end




__END__

def format(instance)
  raise "No instance supplied" unless instance
  raise "Disk not valid" unless self.valid?

  begin
    puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
    ssh_command instance.dns_public, current_user_keypairpath, @@global.user, "mkfs.ext3 -F #{disk.device}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error formatting #{disk.path}: #{ex.message}"
  end
  true
end
def mount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Mounting #{disk.device} to #{disk.path}".bright
    ssh_command instance.dns_public, current_user_keypairpath, @@global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error mounting #{disk.path}: #{ex.message}"
  end
  true
end

def unmount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Unmounting #{disk.path}...".bright
    ssh_command instance.dns_public, current_user_keypairpath, global.user, "umount #{disk.path}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error unmounting #{disk.path}: #{ex.message}"
  end
  true
end
