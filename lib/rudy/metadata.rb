


module Rudy
  module MetaData
    include Rudy::AWS
    extend self
    
    def get(rname)
      @@sdb.get(Rudy::DOMAIN, rname) || nil
    end
    
    def query(qstr)
      @@sdb.query_with_attributes(Rudy::DOMAIN, qstr) || nil
    end
    
    #def destroy(rname)
    #  @@sdb.destroy(Rudy::DOMAIN, rname)
    #end

    module ObjectBase
      include Rudy::AWS
      
      def name; raise "#{self.class} must override 'name'"; end
      def valid?; raise "#{self.class} must override 'valid?'"; end
      
      def to_query(more=[], less=[])
        Rudy::AWS::SimpleDB.generate_query build_criteria(more, less)
      end
    
      def to_select(more=[], less=[])
        Rudy::AWS::SimpleDB.generate_select ['*'], Rudy::DOMAIN, build_criteria(more, less)
      end
    
    
      def save
        @@sdb.store(Rudy::DOMAIN, name, self.to_hash, :replace) # Always returns nil
        true
      end
    
      def destroy
        @@sdb.destroy(Rudy::DOMAIN, name)
        true
      end
    
      def refresh
        h = @@sdb.get(Rudy::DOMAIN, name) || {}
        from_hash(h)
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
