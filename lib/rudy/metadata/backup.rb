
require 'date'

module Rudy
  module MetaData
    class Backup < Storable
      include Rudy::MetaData::ObjectBase
      extend Rudy::MetaData::ObjectBase
        
      @@rtype = "back"
      
      field :rtype
      field :awsid
      
      field :region
      field :zone
      field :environment
      field :role
      field :position
      field :path
      
      field :date
      field :time
      field :second
      
      field :unixtime => Integer
      
      field :size
      field :volume
      
      def initialize
        @zone = DEFAULT_ZONE
        @region = DEFAULT_REGION
        @position = "01"
        @rtype = @@rtype
      end
      
      def rtype
        @@rtype
      end
      
      def self.rtype
        @@rtype
      end
      
      
      def name
        time = Time.at(@unixtime)
        Backup.generate_name(@zone, @environment, @role, @position, @path, time)
      end
      
      def valid?
        @zone && @environment && @role && @position && @path && @date && @time && @second
      end
      
      def time_stamp
        #return [@date, @time] if @date && @time
        now = Time.now.utc
        datetime = Backup.format_timestamp(now).split(RUDY_DELIM)
        @unixtime = now.to_i
        @date, @time, @second = datetime
      end
      
      def nice_time
        return "" unless @date && @time
        t = @date.scan(/(\d\d\d\d)(\d\d)(\d\d)/).join('-')
        t << " " << @time.scan(/(\d\d)(\d\d)/).join(':')
        t
      end
      
      def to_query(more=[], remove=[])
        criteria = [:rtype, :zone, :environment, :role, :position, :path, :date, :time, :second, *more]
        criteria -= [*remove].flatten
        query = "select * from #{RUDY_DOMAIN} where unixtime > '0' "
        criteria.each do |n|
          query << "and #{n} = '#{self.send(n.to_sym)}'"
        end
        query << " order by unixtime desc"
      end
      
      def to_s
        str = ""
        field_names.each do |key|
          str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
        end
        str
       end
      
      def disk
        Disk.generate_name(@zone, @environment, @role, @position, @path)
      end
      
      # 20090224-1813-36
      def Backup.format_timestamp(dat)
        mon, day, hour, min, sec = [dat.mon, dat.day, dat.hour, dat.min, dat.sec].collect { |v| v.to_s.rjust(2, "0") }
        [dat.year, mon, day, RUDY_DELIM, hour, min, RUDY_DELIM, sec].join
      end
      
      # Times are converted to UTC
      # back-us-east-1b-stage-app-01-rilli-app-20090224-1813-36
      def Backup.generate_name(zon, env, rol, pos, pat, dat, sep=File::SEPARATOR)
        raise "The date you provided is not a Time object" unless dat.is_a?(Time)
        pos = pos.to_s.rjust 2, '0'
        dirs = pat.split sep if pat
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        timestamp = Backup.format_timestamp(dat.utc)
        [@@rtype, zon, env, rol, pos, dirs, timestamp].flatten.join(RUDY_DELIM)
      end
      

      def Backup.for_disk(sdb, disk, max=50)
        list = Backup.list(sdb, disk.zone, disk.environment, disk.role, disk.position, disk.path) || []
        list[0..(max-1)]
      end
      
      def Backup.get(sdb, name)
        object = sdb.get_attributes(RUDY_DOMAIN, name)
        raise "Object #{name} does not exist!" unless object.has_key?(:attributes) && !object[:attributes].empty?
        self.from_hash(object[:attributes])
      end
      
      def Backup.save(sdb, obj, replace = :replace)
        sdb.store(RUDY_DOMAIN, obj.name, obj.to_hash, replace)
      end
      
      def Backup.list(sdb, zon, env=nil, rol=nil, pos=nil, path=nil, date=nil)
        query = "select * from #{RUDY_DOMAIN} where "
        query << "rtype = '#{rtype}' "
        query << " and zone = '#{zon}'" if zon
        query << " and environment = '#{env}'" if env
        query << " and role = '#{rol}'" if rol
        query << " and position = '#{pos}'" if pos
        query << " and path = '#{path}'" if path
        query << " and date = '#{date}'" if date
        query << " and unixtime != '0' order by unixtime desc"
        list = []
        sdb.select(query).each do |obj|
          list << self.from_hash(obj)
        end
        list
      end
      
      def Backup.find_most_recent(zon, env, rol, pos, path)
        criteria = [zon, env, rol, pos, path]
        (Rudy::MetaData::Backup.list(@sdb, *criteria) || []).first
      end
      
      def Backup.destroy(sdb, name)
        back = Backup.get(sdb, name) # get raises an exception if the disk doesn't exist
        sdb.destroy(RUDY_DOMAIN, name)
        true # wtf: RightAws::SimpleDB doesn't tell us whether it succeeds. We'll assume!
      end
      

      
      def Backup.is_defined?(sdb, backup)
        query = backup.to_query()
        puts query
        !sdb.select(query).empty?
      end
      
    end
  end
end

