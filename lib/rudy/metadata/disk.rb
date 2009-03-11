

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
        Disk.generate_name(@zone, @environment, @role, @position, @path)
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
       
      def Disk.generate_name(zon, env, rol, pos, pat, sep=File::SEPARATOR)
        pos = pos.to_s.rjust 2, '0'
        dirs = pat.split sep if pat
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        ["disk", zon, env, rol, pos, *dirs].join(RUDY_DELIM)
      end
      
      def Disk.get(sdb, name)
        disk = sdb.get_attributes(RUDY_DOMAIN, name)
        
        raise "Disk #{name} does not exist!" unless disk && disk.has_key?(:attributes)
        Rudy::MetaData::Disk.from_hash(disk[:attributes])
      end
      
      def Disk.destroy(sdb, disk)
        disk = Disk.get(sdb, disk) if disk.is_a?(String) # get raises an exception if the disk doesn't exist
        sdb.destroy(RUDY_DOMAIN, disk.name)
        true # wtf: RightAws::SimpleDB doesn't tell us whether it succeeds. We'll assume!
      end
      
      def Disk.save(sdb, disk)
        sdb.store(RUDY_DOMAIN, disk.name, disk.to_hash, :replace)
      end
      
      def Disk.is_defined?(sdb, disk)
        # We don't care about the path, but we do care about the device
        # which is not part of the disk's name. 
        query = disk.to_query(:device, :path)
        !sdb.query_with_attributes(RUDY_DOMAIN, query).empty?
      end
      
      def Disk.find_from_volume(sdb, vol_id)
        query = "['awsid' = '#{vol_id}']"
        res = sdb.query_with_attributes(RUDY_DOMAIN, query)
        if res.empty?
          nil
        else
          disk = Rudy::MetaData::Disk.from_hash(res.values.first)
        end
      end
      
      
      def Disk.list(sdb, zon, env=nil, rol=nil, pos=nil)
        query = ''
        query << "['rtype' = '#{@@rtype}']" if zon
        query << " intersection ['zone' = '#{zon}']" if zon
        query << " intersection ['environment' = '#{env}']" if env
        query << " intersection ['role' = '#{rol}']" if rol
        query << " intersection ['position' = '#{pos}']" if pos
        
        list = []
        sdb.query_with_attributes(RUDY_DOMAIN, query).each_pair do |name, hash|
          #puts "DISK: #{hash.to_yaml}"
          list << Rudy::MetaData::Disk.from_hash(hash)
        end
        list
      end
    end
    
  end

end
