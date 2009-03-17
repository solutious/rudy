

module Rudy
  
  module MetaData
    class Disk < Storable
      
      @@rtype = 'disk'
      
        # This is a flag used internally to specify that a volume has been
        # created for this disk, but not formated. 
      attr_accessor :raw_volume
      
      field :rtype
      field :awsid
      
      field :environment
      field :role
      field :path
      field :position
      
      field :zone
      field :region
      field :device
      #field :backups => Array
      field :size
      
      def initialize
        @backups = []
        @rtype = @@rtype.to_s
        @raw_volume = false
      end
      
      def rtype
        @@rtype.to_s
      end
      
      def rtype=(val)
      end
      
      def name
        Rudy::Disks.generate_name(@zone, @environment, @role, @position, @path)
      end
      
      def valid?
        @zone && @environment && @role && @position && @path && @size && @device
      end
      
      def to_query(more=[], remove=[])
        criteria = [:rtype, :zone, :environment, :role, :position, :path, *more]
        criteria -= [*remove].flatten
        query = []
        criteria.each do |n|
          query << "['#{n}' = '#{self.send(n.to_sym)}'] "
        end
        query.join(" intersection ")
      end
      
      def to_s
        str = ""
        field_names.each do |key|
          str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
        end
        str
      end
       
    end
    
  end

end
