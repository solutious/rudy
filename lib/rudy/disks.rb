

module Rudy
  class Disks
    include Rudy::Huxtable
    
    def initialize(opts={})
      super(opts)
      @disk_handler = Rudy::Routines::DiskHandler.new(opts)
    end
    
    def generate_name(zon, env, rol, pos, pat, sep=File::SEPARATOR)
      pos = pos.to_s.rjust 2, '0'
      dirs = pat.split sep if pat
      dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
      ["disk", zon, env, rol, pos, *dirs].join(RUDY_DELIM)
    end
    
    def get(name)
      disk = @sdb.get_attributes(RUDY_DOMAIN, name)
      return nil unless disk && disk.has_key?(:attributes) && !disk[:attributes].empty?
#        raise "Disk #{name} does not exist!" unless 
      Rudy::MetaData::Disk.from_hash(disk[:attributes]) || nil
    end
    
    def save(disk)
      @sdb.store(RUDY_DOMAIN, disk.name, disk.to_hash, :replace)
    end
    
    def is_defined?(disk)
      # We don't care about the path, but we do care about the device
      # which is not part of the disk's name. 
      query = disk.to_query(:device, :path)
      !@sdb.query_with_attributes(RUDY_DOMAIN, query).empty?
    end
    
    def create(opts={})
      opts, instances = process_filter_options(opts)
      
      disk = Rudy::MetaData::Disk.new
      [:region, :zone, :environment, :role, :position].each do |n|
        disk.send("#{n}=", @global.send(n)) if @global.send(n)
      end
      
      [:path, :device, :size].each do |n|
        disk.send("#{n}=", opts[n]) if opts[n]
      end
      
      raise "Not enough info was provided to define a disk (#{disk.name})" unless disk.valid?
      #raise "The device #{disk.device} is already in use on that machine" if is_defined?(disk)
      
      #p instances
      
      instances.each_pair do |id, machine|
        @disk_handler.create_disk(machine, disk)
      end
      
      
     # puts "Creating volume... (#{disk.size}GB in #{@global.zone})"
     # volume = @ec2.volumes.create(@global.zone, disk.size)
     # sleep 3
     # 
     # disk.awsid = volume[:aws_id]
     # disk.raw_volume = true    # This value is not saved. 
     # Rudy::MetaData::Disk.save(@sdb, disk)
     # 
     # execute_attach_disk(disk, machine)
      
    end
    
    def list(opts={})
      opts = {
        :all => false
      }.merge(opts)
      
      query = ''
      query << "['rtype' = 'disk']"
      unless opts[:all]
        [:region, :zone, :environment, :role, :position].each do |n|
           query << " intersection ['#{n}' = '#{@global.send(n)}']" if @global.send(n)
        end
      end
      puts query
      list = []
      @sdb.query_with_attributes(RUDY_DOMAIN, query).each_pair do |name, hash|
        #puts "DISK: #{hash.to_yaml}"
        list << Rudy::MetaData::Disk.from_hash(hash)
      end
      list
      
    end





    
    def destroy(sdb, disk)
      disk = get(sdb, disk) if disk.is_a?(String) # get raises an exception if the disk doesn't exist
      sdb.destroy(RUDY_DOMAIN, disk.name)
      true # wtf: RightAws::SimpleDB doesn't tell us whether it succeeds. We'll assume!
    end
    
    
    def find_from_volume(sdb, vol_id)
      query = "['awsid' = '#{vol_id}']"
      res = sdb.query_with_attributes(RUDY_DOMAIN, query)
      if res.empty?
        nil
      else
        disk = Rudy::MetaData::Disk.from_hash(res.values.first)
      end
    end
    
    
    def find_from_path(sdb, path)
      query = "['path' = '#{path}']"
      res = sdb.query_with_attributes(RUDY_DOMAIN, query)
      if res.empty?
        nil
      else
        disk = Rudy::MetaData::Disk.from_hash(res.values.first)
      end
    end

    private
      def process_filter_options(opts)
        opts = { :group => current_machine_group, :id => nil, :state => :running }.merge(opts)
        raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
        opts[:id] &&= [opts[:id]].flatten
        instances = opts[:id] ? @ec2.instances.list(opts[:id], opts[:state]) : @ec2.instances.list_by_group(opts[:group], opts[:state])
        raise "No machines running" unless instances && !instances.empty?
        [opts, instances]
      end
      
  end
end