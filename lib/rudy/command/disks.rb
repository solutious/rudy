
module Rudy
class Disks
  include Rudy::Huxtable
  extend Rudy::MetaData
  
  
  def self.get(rname)
    Rudy::Disk.from_hash(super(rname)) # Returns nil if empty
  end
  
end
end

module Rudy
class Disk < Storable
  include Rudy::Huxtable
  include Rudy::MetaData::ObjectBase
  
  field :rtype
  field :awsid
  
  field :region
  field :zone
  field :environment
  field :role
  field :position
  field :path
  
  field :device
  field :size
  #field :backups => Array
  
  def init
    @rtype = 'disk'
    @region = @@global.region
    @zone = @@global.zone
    @environment = @@global.environment
    @role = @@global.role
    @position = @@global.position
  end
  
  def name
    Disk.generate_name(@zone, @environment, @role, @position, @path)
  end

  def Disk.generate_name(zon, env, rol, pos, pat, sep=File::SEPARATOR)
    pos = pos.to_s.rjust 2, '0'
    dirs = pat.split sep if pat && !pat.empty?
    dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
    ["disk", zon, env, rol, pos, *dirs].join(Rudy::DELIM)
  end
  
  def to_query(more=[], less=[])
    super([:path, *more], less)  # Add path to the default fields
  end
  
  def to_select(more=[], less=[])
    super([:path, *more], less) 
  end
  
  def to_s
    str = ""
    field_names.each do |key|
      str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
    end
    str
  end
  
  def ==(other)
    self.name == other.name
  end
end
end