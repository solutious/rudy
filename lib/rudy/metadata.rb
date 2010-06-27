

module Rudy
  module Metadata
    include Rudy::Huxtable
    
    COMMON_FIELDS = [:region, :zone, :environment, :role].freeze
    
    @@rsdb   = nil
    @@domain = Rudy::DOMAIN
    
    #
    def self.get_rclass(rtype)
      case rtype
      when Rudy::Machines::RTYPE
        Rudy::Machines
      when Rudy::Disks::RTYPE
        Rudy::Disks
      when Rudy::Backups::RTYPE
        Rudy::Backups
      else
        raise UnknownRecordType, rtype
      end
    end
    
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
      true
    end
    
    # Get a record from SimpleDB with the key +n+
    def self.get(n) 
      Rudy::Huxtable.ld "GET: #{n}" if Rudy.debug?
      @@rsdb.get @@domain, n
    end
    
    def self.exists?(n)
      !get(n).nil?
    end
    
    def self.put(n, o, replace=false)
      Rudy::Huxtable.ld "PUT: #{n}" if Rudy.debug?
      @@rsdb.put @@domain, n, o, replace
    end
    
    def self.destroy(n)
      Rudy::Huxtable.ld "DESTROY: #{n}" if Rudy.debug?
      @@rsdb.destroy @@domain, n
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
    # * +rtype+ is the record type. One of: m, disk, or back.
    # * +fields+ replaces and adds values to this criteria
    # * +less+ removes keys from the default criteria. 
    #
    # Returns a Hash. 
    def self.build_criteria(rtype, fields={}, less=[])
      fields ||= {}
      fields[:rtype] = rtype
      fields[:position] = @@global.position unless @@global.position.nil?
      names = Rudy::Metadata::COMMON_FIELDS
      values = names.collect { |n| @@global.send(n.to_sym) }
      mixer = names.zip(values).flatten
      criteria = Hash[*mixer].merge(fields)
      criteria.reject! { |n,v| less.member?(n) }
      Rudy::Huxtable.ld "CRITERIA: #{criteria.inspect}"
      criteria
    end
    
    
    # These methods are common to all plural metadata classes:
    # Rudy::Machines, Rudy::Disks, Rudy::Backups, etc...
    # 
    module ClassMethods
      extend self
      extend Rudy::Huxtable
      
      def list(fields={}, less=[], &block)
        fields = Rudy::Metadata.build_criteria self::RTYPE, fields, less
        records_raw, records = Rudy::Metadata.select(fields), []
        return nil if records_raw.nil? || records_raw.empty?
        records_raw.each_pair do |key, r|
          obj = self.from_hash r
          records << obj
        end
        records.sort { |a,b| a.name <=> b.name }
      end

      def list_as_hash(fields={}, less=[], &block)
        fields = Rudy::Metadata.build_criteria self::RTYPE, fields, less
        records_raw, records = Rudy::Metadata.select(fields), {}
        return nil if records_raw.nil? || records_raw.empty?
        records_raw.each_pair do |p, r|
          obj = self.from_hash r
          records[p] = obj
        end
        records
      end
      
      def any?(fields={}, less=[])
        !list(fields, less).nil?
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
      obj.send :include, Rudy::Metadata::InstanceMethods
      
      # Add common storable fields. 
      [COMMON_FIELDS, :position].flatten.each do |n|
        obj.field n
      end
      
    end
    
    def initialize(rtype, opts={})
      @rtype = rtype
      @position = position || @@global.position || '01'
      
      COMMON_FIELDS.each { |n|
        ld "SETTING: #{n}: #{@@global.send(n)}" if @@global.verbose > 3
        instance_variable_set("@#{n}", @@global.send(n))
      }
      
      opts.each_pair do |n,v|
        raise "Unknown attribute for #{self.class}: #{n}" if !self.has_field? n
        next if v.nil?
        ld "RESETTING: #{n}: #{v}" if @@global.verbose > 3
        self.send("#{n}=", v)
      end
      
    end
    
    def name(*other)
      parts = [@rtype, @zone, @environment, @role, @position, *other].flatten
      parts.join Rudy::DELIM
    end
    
    def save(replace=false)
      raise DuplicateRecord, self.name unless replace || !self.exists?
      Rudy::Metadata.put self.name, self.to_hash, replace
      true
    end
    
    def destroy(force=false)
      raise UnknownObject, self.name unless self.exists?
      Rudy::Metadata.destroy self.name
      true
    end
    
    def descriptors(*additional)
      criteria = {
        :region => @region,  :zone => @zone,
        :environment => @environment, :role => @role
      }
      additional.each do |att|
        criteria[att] = self.send(att)
      end
      ld "DESCRIPTORS: #{criteria.inspect} (#{additional})"
      criteria
    end
    
    # Refresh the metadata object from SimpleDB. If the record doesn't 
    # exist it will raise an UnknownObject error 
    def refresh!
      raise UnknownObject, self.name unless self.exists?
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
    
    
    
    

    class UnknownRecordType < Rudy::Error
      def message; "Unknown record type: #{@obj}"; end
    end
    class UnknownObject < Rudy::Error
      def message; "Unknown object: #{@obj}"; end
    end
    # Raised when trying to save a record with a key that already exists
    class DuplicateRecord < Rudy::Error; end
    
  end
  autoload :Backup, 'rudy/metadata/backup'
  autoload :Disk, 'rudy/metadata/disk'
  autoload :Machine, 'rudy/metadata/machine'
end


