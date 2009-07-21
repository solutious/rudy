

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    class UnknownRecord < Rudy::Error; end
    
    @@rsdb = nil
    @@rvol = nil
    
    @@domain = Rudy::DOMAIN
    
    # Creates instances of the following and stores to class variables:
    # * Rudy::AWS::SDB
    # * Rudy::AWS::EC2::Volumes
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
      @@domain = n if @@rsdb.create_domain n
    end
    
    # Destroys a SimpleDB domain named +n+ and sets +@@domain+ to Rudy::DOMAIN
    def self.destroy_domain(n)
      @@rsdb.destroy_domain n
      @@domain = Rudy::DOMAIN
    end
    
    # Get a record from SimpleDB with the key +n+
    def self.get(n)
      @@rsdb.get @@domain, n
    end
    
    def self.select(fields={})
      squery = Rudy::AWS::SDB.generate_select @@domain, fields
      @@rsdb.select squery
    end
    
    def self.build_criteria(fields={}, less=[])
      names = [:region, :zone, :environment, :role]
      names << :position unless @@global.position.nil?
      names -= [*less].flatten.uniq.compact
      values = names.collect { |n| @@global.send(n.to_sym) }
      fields.merge(Hash[names.zip(values)])
    end
    
    module ClassMethods
      extend self

      def list(fields={}, less=[], &block)
        fields = Rudy::Metadata.build_criteria fields, less
        records_raw, records = Rudy::Metadata.select(fields), []
        return nil if records_raw.nil? || records_raw.empty?
        records_raw.each_pair do |p, r|
          obj = self.from_hash r
          records << obj
        end
        records
      end

      def list_as_hash(fields={}, less=[], &block)
        fields = Rudy::Metadata.build_criteria fields, less
        records_raw, records = Rudy::Metadata.select(fields), {}
        return nil if records_raw.nil? || records_raw.empty?
        records_raw.each_pair do |p, r|
          obj = self.from_hash r
          records[p] = obj
        end
        records
      end
    end
    
    # All classes which include Rudy::Metadata must reimplement
    # the method stubs in this module. These methods only raise
    # exceptions. 
    module InstanceMethods
      class << self
        def valid?; raise "implement valid?"; end
        def name; raise "implement name"; end
      end 
    end
    
    def self.included(obj)
      obj.extend Rudy::Metadata::ClassMethods
      obj.send :include, Rudy::Metadata::InstanceMethods
      
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
      raise DuplicateRecord, self.name unless replace || !self.exists?
      @@rsdb.put @@domain, self.name, self.to_hash, replace
      true
    end
    
    def destroy(force=false)
      raise UnknownRecord, self.name unless self.exists?
      @@rsdb.destroy @@domain, self.name
      true
    end
    
    def refresh
      h = Rudy::Metadata.get self.name
      self.from_hash(h)
    end
    
    # Compares the names between two Rudy::Metadata objects. 
    def ==(other)
      return false unless other === self.class
      self.name == other.name
    end
    
    # Is there an object in SimpleDB where the key == self.name
    def exists?
      !Rudy::Metadata.get(self.name).nil?
    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'metadata', '*.rb')

