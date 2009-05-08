

module Rudy
  module MetaData
    module ObjectBase
      include Rudy::Huxtable
      
      def initialize(*args)
        a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
        @sdb = Rudy::AWS::SDB.new(a, s, r)
        @ec2inst = Rudy::AWS::EC2::Instances.new(a, s, r)
        @rvol = Rudy::AWS::EC2::Volumes.new(a, s, r)
        @radd = Rudy::AWS::EC2::Addresses.new(a, s, r)
        @rsnap = Rudy::AWS::EC2::Snapshots.new(a, s, r)
        init(*args)
      end
      
      def init(*args); raise "Must override init"; end
      
      def valid?; raise "#{self.class} must override 'valid?'"; end
      
      def to_query(more=[], less=[])
        Rudy::AWS::SDB.generate_query build_criteria(more, less)
      end
    
      def to_select(more=[], less=[])
        Rudy::AWS::SDB.generate_select ['*'], Rudy::DOMAIN, build_criteria(more, less)
      end
      
      def name(identifier, zon, env, rol, pos, *other)
        pos = pos.to_s.rjust 2, '0'
        [identifier, zon, env, rol, pos, *other].flatten.compact.join(Rudy::DELIM)
      end
      
      def save(replace=true)
        replace = true if replace.nil?
        @sdb ||= Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
        @sdb.put(Rudy::DOMAIN, name, self.to_hash, replace) # Always returns nil
        true
      end
    
      def destroy
        @sdb ||= Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
        @sdb.destroy(Rudy::DOMAIN, name)
        true
      end
    
      def refresh
        @sdb ||= Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
        h = @sdb.get(Rudy::DOMAIN, name) || {}
        from_hash(h)
      end
      
      def ==(other)
        return false unless other.is_a?(self.class)
        self.name == other.name
      end
      
      # A generic default
      def to_s
        str = ""
        field_names.each do |key|
          str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
        end
        str
      end
      
      def liner_note
        info = @awsid && !@awsid.empty? ? @awsid : "[no aws object]"
        "%s  %s" % [self.name.bright, info]
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
      
    protected
    
      # Builds a zipped Array from a list of criteria.
      # The list of criteria is made up of metadata object attributes. 
      # The list is constructed by taking the adding +more+, and
      # subtracting +less+ from <tt>:rtype, :region, :zone, :environment, :role, :position</tt>
      # 
      # Returns [[:rtype, value], [:zone, value], ...]
      def build_criteria(more=[], less=[])
        criteria = [:rtype, :region, :zone, :environment, :role, :position, *more].compact
        criteria -= [*less].flatten.uniq.compact
        values = criteria.collect do |n|
          self.send(n.to_sym)
        end
        criteria.zip(values)
      end
      
    end
  end
end

