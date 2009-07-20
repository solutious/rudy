

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    
    @@sdb = nil
    @@domain = Rudy::DOMAIN
    
    def self.connect(accesskey, secretkey, region, reconnect=false)
      return @@sdb unless reconnect || @@sdb.nil?
      @@sdb = Rudy::AWS::SDB.new accesskey, secretkey, region
    end
    def self.domain(name=nil)
      return @@domain if name.nil?
      @@domain = name
    end
    # An alias for Rudy::Metadata.domain
    def self.domain=(*args)
      domain *args
    end

    def self.get(n)
      Rudy::Huxtable.ld [:sdb_get, n]
      ret = @@sdb.get(@@domain, n)
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
      @@sdb.put(@@domain, self.name, self.to_hash, replace) # Returns nil
      true
    end
    
    def refresh
      h = Rudy::Metadata.get self.name
      self.from_hash(h)
    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'metadata', '*.rb')