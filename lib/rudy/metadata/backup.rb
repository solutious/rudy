module Rudy::MetaData
    class Backup < Storable
    include Rudy::MetaData::ObjectBase
    
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
    
    field :created => Integer
    
    field :size
    field :volume
    
    require 'date'

    
    def init(volume=nil, path=nil, position=nil)
      # NOTE: Arguments must be optional or Storable will raise an exception!
      @volume= volume
      @path = path
      @rtype = 'back'
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = position || @@global.position
      
      
      now = Time.now.utc
      datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = now.to_i
      @date, @time, @second = datetime
      
      postprocess
    end
    
    def to_s(with_titles=true)
      update
      mtd = @mounted == true ? "mounted" : @status
      "%s; %3sGB; %s; %s" % [liner_note, @size, @device, mtd]
    end

    def name
      sep=File::SEPARATOR
      dirs = @path.split sep if @path && !@path.empty?
      dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
      super("back", @zone, @environment, @role, @position, *dirs, @date, @time, @second)
    end
    
    def nice_time
      return "" unless @date && @time
      t = @date.scan(/(\d\d\d\d)(\d\d)(\d\d)/).join('-')
      t << " " << @time.scan(/(\d\d)(\d\d)/).join(':')
      t
    end
    
    def to_s
      str = ""
      field_names.each do |key|
        str << sprintf(" %22s: %s#{$/}", key, self.send(key.to_sym))
      end
      str
     end
    
    def diskname
      Rudy::MetaData::Disk.new(@path, nil, nil, @position).name
    end
    
    def create(volume=nil)
      volume ||= @volume
      vol = @rsnap.create(volume) 
      @awsid = vol.awsid
      self.save
      self
    end
    
    # 20090224-1813-36
    def Backup.format_timestamp(dat)
      mon, day, hour, min, sec = [dat.mon, dat.day, dat.hour, dat.min, dat.sec].collect { |v| v.to_s.rjust(2, "0") }
      [dat.year, mon, day, Rudy::DELIM, hour, min, Rudy::DELIM, sec].join
    end
    
    def to_query(more=[], less=[])
      query = super([:path, :date, :time, :second, *more], less)
    end

    def to_select(more=[], less=[])
      query = super([:path, :date, :time, :second, *more], less) 
    end

    # Does this disk have enough info to be saved or used?
    # The test is based on the same criteria for building
    # SimpleDB queries. 
    def valid?
      criteria = build_criteria([:path]).flatten
      criteria.size == criteria.compact.size
    end
    
  end
end

