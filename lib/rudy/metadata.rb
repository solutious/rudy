

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    class UnknownRecord < Rudy::Error; end
    
    @@rsdb   = nil
    @@rvol   = nil
    @@rinst  = nil 
    @@radd   = nil
    @@rkey   = nil 
    @@rgrp   = nil
    @@domain = Rudy::DOMAIN
    
    # Creates instances of the following and stores to class variables:
    # * Rudy::AWS::SDB
    # * Rudy::AWS::EC2::Volumes
    def self.connect(accesskey, secretkey, region, reconnect=false)
      return @@rsdb unless reconnect || @@rsdb.nil?
      @@rsdb  = Rudy::AWS::SDB.new accesskey, secretkey, region
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
      Rudy::Huxtable.ld "DESTROY: #{n}" if Rudy.debug?
      @@rsdb.destroy_domain n
      @@domain = Rudy::DOMAIN
    end
    
    # Get a record from SimpleDB with the key +n+
    def self.get(n)
      Rudy::Huxtable.ld "GET: #{n}" if Rudy.debug?
      @@rsdb.get @@domain, n
    end
    
    # Generates and executes a SimpleDB select query based on
    # the specified +fields+ Hash. See self.build_criteria.
    #
    # Returns a Hash. keys are SimpleDB object IDs and values
    # are the object attributes. 
    def self.select(fields={})
      squery = Rudy::AWS::SDB.generate_select @@domain, fields
      Rudy::Huxtable.ld "SELECT: #{squery}" if Rudy.debug?
      @@rsdb.select squery
    end
    
    # Generates a default criteria for all metadata based on
    # region, zone, environment, and role. If a position has
    # been specified in the globals it will also be included.
    # +fields+ replaces and adds values to this criteria and
    # +less+ removes keys from the default criteria. 
    #
    # Returns a Hash. 
    def self.build_criteria(rtype, fields={}, less=[])
      fields ||= {}
      fields[:rtype] = rtype
      fields[:position] = @@global.position unless @@global.position.nil?
      names = [:region, :zone, :environment, :role]
      names -= [*less].flatten.uniq.compact
      values = names.collect { |n| @@global.send(n.to_sym) }
      Hash[names.zip(values)].merge(fields)
    end
    
    module ClassMethods
      extend self
      extend Rudy::Huxtable
      
      # TODO: MOVE TO Rudy:Disks etc...
      def list(fields={}, less=[], &block)
        fields = Rudy::Metadata.build_criteria self::RTYPE, fields, less
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
        def postprocess; raise "implement postprocess"; end
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
    
    def initialize(rtype, opts={})
      @rtype = rtype
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = position || @@global.position || '01'
      
      opts.each_pair do |n,v|
        raise "Unknown attribute for #{self.class}: #{n}" if !self.has_field? n
        self.send("#{n}=", v)
      end
      
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
    
    # Refresh the metadata object from SimpleDB. If the record doesn't 
    # exist it will raise an UnknownRecord error 
    def refresh
      raise UnknownRecord, self.name unless self.exists?
      h = Rudy::Metadata.get self.name
      return false if h.nil? || h.empty?
      obj = self.from_hash(h)
      obj.postprocess
      obj
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

