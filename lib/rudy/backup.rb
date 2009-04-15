
require 'date'

module Rudy
  module MetaData
    class Backup < Storable
      include Rudy::AWS
      
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
        @rtype = Backup.rtype
        time_stamp # initialize time to right now
      end
      
      def self.rtype
        'back'
      end
      
      
      def name
        time = Time.at(@unixtime)
        Backup.generate_name(@zone, @environment, @role, @position, @path, time)
      end
      
      def valid?
        #puts(@zone, @environment, @role, @position, @path, @date, @time, @second)
        (@zone && @environment && @role && @position && @path && @date && @time && @second)
      end
      
      def time_stamp
        #return [@date, @time] if @date && @time
        now = Time.now.utc
        datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
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
        query = "select * from #{Rudy::DOMAIN} where unixtime > '0' "
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
        [dat.year, mon, day, Rudy::DELIM, hour, min, Rudy::DELIM, sec].join
      end
      
      # Times are converted to UTC
      # back-us-east-1b-stage-app-01-rilli-app-20090224-1813-36
      def Backup.generate_name(zon, env, rol, pos, pat, dat, sep=File::SEPARATOR)
        raise "The date you provided is not a Time object" unless dat.is_a?(Time)
        pos = pos.to_s.rjust 2, '0'
        dirs = pat.split sep if pat
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        timestamp = Backup.format_timestamp(dat.utc)
        [rtype, zon, env, rol, pos, dirs, timestamp].flatten.join(Rudy::DELIM)
      end
      
      
      
      
      def to_select
        
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
      
      def Backup.get(dname)
        h = @@sdb.get(Rudy::DOMAIN, dname) || {}
        from_hash(h)
      end
      
    end
  end
end

