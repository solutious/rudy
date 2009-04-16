


module Rudy
  module MetaData

    # 20090224-1813-36
    def format_timestamp(dat)
      mon, day, hour, min, sec = [dat.mon, dat.day, dat.hour, dat.min, dat.sec].collect { |v| v.to_s.rjust(2, "0") }
      [dat.year, mon, day, Rudy::DELIM, hour, min, Rudy::DELIM, sec].join
    end
    
    module ObjectBase
      include Rudy::Huxtable
      
      def initialize
        @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
        @ec2inst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
        init
      end
      
      def init; raise "Must override init"; end
      
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
        self.name == other.name
      end
      
      def to_s
        str = ""
        field_names.each do |key|
          str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
        end
        str
      end

      
    protected
    
      # Builds a zipped Array from a list of criteria.
      # The list of criteria is made up of metadata object attributes. 
      # The list is constructed by taking the adding +more+, and
      # subtracting +less+ from <tt>:rtype, :zone, :environment, :role, :position</tt>
      # Returns [[:rtype, value], [:zone, value], ...]
      def build_criteria(more=[], less=[])
        criteria = [:rtype, :zone, :environment, :role, :position, *more].compact
        criteria -= [*less].flatten.uniq.compact
        values = criteria.collect do |n|
          self.send(n.to_sym)
        end
        criteria.zip(values)
      end
    end
  end
end
