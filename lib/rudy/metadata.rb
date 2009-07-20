

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    
    @@rsdb = nil
    @@rvol = nil
    
    @@domain = Rudy::DOMAIN
    
    def self.connect(accesskey, secretkey, region, reconnect=false)
      return @@rsdb unless reconnect || @@rsdb.nil?
      @@rsdb = Rudy::AWS::SDB.new accesskey, secretkey, region
      @@rvol = Rudy::AWS::EC2::Volumes.new accesskey, secretkey, region
      true
    end
    def self.domain(name=nil)
      return @@domain if name.nil?
      @@domain = name
    end
    # An alias for Rudy::Metadata.domain
    def self.domain=(*args)
      domain *args
    end
    
    # Creates a SimpleDB domain named +n+ and updates +@@domain+ if successful
    def self.create_domain(n)
      domain = n if @@rsdb.create_domain n
    end
    
    # Destroys a SimpleDB domain named +n+ and sets +@@domain+ to Rudy::DOMAIN
    def self.destroy_domain(n)
      @@rsdb.destroy_domain n
      domain Rudy::DOMAIN
    end
    
    # Get a record from SimpleDB with the key +n+
    def self.get(n)
      Rudy::Huxtable.ld [:sdb_get, n]
      ret = @@rsdb.get(@@domain, n)
      Rudy::Huxtable.ld [:found, ret]
      ret
    end
    
    
    module ClassMethods
      extend self 
      
    end
    
    def self.included(obj)
      obj.extend Rudy::Metadata::ClassMethods  
      
      # Add common storable fields
      obj.field :region
      obj.field :zone
      obj.field :environment
      obj.field :role
      obj.field :position
    end
    
    def initialize(rtype)
      Rudy::Metadata.connect @@global.accesskey, @@global.secretkey, @@global.region
      @rtype = rtype
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = position || @@global.position || '01'
    end
    
    def name(*other)
      parts = [@rtype, @zone, @environment, @role, @position, *other].flatten
      parts.join Rudy::DELIM
    end
    
    def save(replace=false)
      unless replace || Rudy::Metadata.get(self.name).nil?
        raise DuplicateRecord, self.name 
      end
      @@rsdb.put(@@domain, self.name, self.to_hash, replace) # Returns nil
      true
    end
    
    def refresh
      h = Rudy::Metadata.get self.name
      self.from_hash(h)
    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'metadata', '*.rb')