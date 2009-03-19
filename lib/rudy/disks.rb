

module Rudy
  class Disks
    include Rudy::Huxtable
    
    def initialize(opts={})
      super(opts)
      @disk_handler = Rudy::Routines::DiskHandler.new(opts)
      @volumes = Rudy::Volumes.new(opts)
    end
    
    def create(instance=nil, opts={})
      disk = find_disk_from_opts(opts, :create)
      switch_user(:root)
      
      raise "Not enough info was provided to define a disk (#{disk.name})" unless disk.valid?
      raise "The path #{disk.path} is already in use on that machine" if is_defined?(disk)
      raise "The device #{disk.device} is already in use on that machine" if device_used?(disk)

      if is_defined?(disk)
        @logger.puts "The disk #{disk.name} already exists."
        @logger.puts "You can define when to destroy the disk OR"
        @logger.puts "remove the create entry and the disk will"
        @logger.puts "automatically be re-attached when appropriate."
        @logger.puts "Skipping..."
        return
      end
      
      unless disk.size.kind_of?(Integer)
        @logger.puts "Skipping disk for #{disk.path} (size not defined)"
        return
      end
  
      if disk.path.nil?
        @logger.puts "Skipping disk for #{disk.path} (no path defined)"
        return
      end
  
      unless disk.valid?
        @logger.puts "Skipping #{disk.name} (not enough info)"
        return
      end
      
      
      begin
        if instance && @ec2.instances.attached_volume?(instance.awsid, disk.device)
          @logger.puts "Skipping disk for #{disk.path} (device #{disk.device} is in use)"
          return
        end
        
        @logger.puts "Creating Volume..."
        vol = @ec2.volumes.create(disk.zone, disk.size)
        disk.awsid = vol.awsid
        sleep 5 # Replace with waiter
        
        @volumes.attach(instance.awsid, disk.awsid, disk.device)
        
        format(instance, disk)
        mount(instance, disk)
        
      rescue => ex
        @logger.puts "There was an error creating #{disk.path}: #{ex.message}".color(:red)
        @logger.puts ex.backtrace if debug?
        if vol
          @logger.puts "Destroying Volume #{vol.awsid}...".color(:red)
          destroy(instance, disk)
        end
        return
      end
      
      save(disk)
      
      disk
    end
    
    
    def destroy(instance, opts)
      raise "No instance supplied" unless instance
      disk = find_disk_from_opts(opts)

      raise "Must supply a disk" unless disk
      begin
        
        unmount(instance, disk)
        
        if disk.awsid && !disk.awsid.empty?
          @volumes.dettach(disk.awsid)
          @volumes.destroy(disk.awsid)
        end
        
      rescue => ex
        puts "Error while detaching volume #{disk.awsid}: #{ex.message}"
        puts ex.backtrace if debug?
        puts "Continuing..."
      ensure
        puts "Deleteing metadata for #{disk.name}"
        @sdb.destroy(RUDY_DOMAIN, disk.name)
      end
    end
    
    def format(instance, opts={})
      raise "No instance supplied" unless instance
      disk = find_disk_from_opts(opts)
      switch_user(:root)
      
      begin
        puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
        ssh_command instance.dns_name_public, current_user_keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
        sleep 3
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error formatting #{disk.path}: #{ex.message}"
      end
      true
    end
    def mount(instance, opts={})
      raise "No instance supplied" unless instance
      disk = find_disk_from_opts(opts)
      switch_user(:root)
      begin
        puts "Mounting #{disk.device} to #{disk.path}".bright
        ssh_command instance.dns_name_public, current_user_keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error mounting #{disk.path}: #{ex.message}"
      end
      true
    end
    
    def unmount(instance, opts={})
      raise "No instance supplied" unless instance
        disk = find_disk_from_opts(opts)
        switch_user(:root)
      begin
        puts "Unmounting #{disk.path}...".bright
        ssh_command instance.dns_name_public, current_user_keypairpath, global.user, "umount #{disk.path}"
        sleep 2
      rescue => ex
        @logger.puts ex.backtrace if debug?
        raise "Error unmounting #{disk.path}: #{ex.message}"
      end
      true
    end
    
    def list(opts={})
      opts = {
        :all => false
      }.merge(opts)
      disk = find_disk_from_opts(opts)
      query = opts[:all] ? disk.to_query([], [:zone, :environment, :role, :position, :path]) : disk.to_query
      items = execute_query(query)
    end
    def find_from_volume(vol_id)
      query = "['awsid' = '#{vol_id}']"
      items = execute_query(query) || {}
      items.values.first
    end
    def find_from_path(path)
      query = "['path' = '#{path}']"
      items = execute_query(query) || {}
      items.values.first
    end

    def get(name)
      disk = @sdb.get_attributes(RUDY_DOMAIN, name)
      return nil unless disk && disk.is_a?(Hash) && !disk.empty?
      Rudy::MetaData::Disk.from_hash(disk) || nil
    end

    def save(disk)
      @sdb.store(RUDY_DOMAIN, disk.name, disk.to_hash, :replace)
    end

    def is_defined?(disk)
      # We don't care about the path, but we do care about the device
      # which is not part of the disk's name. 
      query = disk.to_query
      !(@sdb.query_with_attributes(RUDY_DOMAIN, query) || {}).empty?
    end

    def device_used?(disk)
      # We don't care about the path, but we do care about the device
      # which is not part of the disk's name. 
      query = disk.to_query(:device, :path)
      !(@sdb.query_with_attributes(RUDY_DOMAIN, query) || {}).empty?
    end
    
  private
    
    def execute_query(query)
      items = @sdb.query_with_attributes(RUDY_DOMAIN, query)
      return nil if !items || items.empty?
      clean_items = {}
      items.flatten.each do |disk|
        next unless disk.is_a?(Hash)
        name = disk.delete("Name")
        clean_items[name] = Rudy::MetaData::Disk.from_hash(disk)
        break
      end
      clean_items
    end
    
    def find_disk_from_opts(opts, create=false)
      raise Exception, "No options given!", caller unless opts
      
      return opts if opts.is_a?(Rudy::MetaData::Disk)
      # Try to load based on the name if supplied
      if opts[:name]
        disk = get(opts[:name])
        raise "Disk #{opts[:name]} does not exist" unless disk
      elsif opts[:path] && !opts[:device] && !opts[:size]
        disk = find_from_path(opts[:path])
        raise "Disk: #{opts[:path]} does not exist"if !disk && !create
      end
      
      if !disk && create
        disk = Rudy::MetaData::Disk.new
        [:region, :zone, :environment, :role, :position].each do |n|
          disk.send("#{n}=", @global.send(n)) if @global.send(n)
        end
      
        [:path, :device, :size].each do |n|
          disk.send("#{n}=", opts[n]) if opts[n]
        end
      end
      
      #raise "The disk is in another machine environment" unless @global.environment.to_s == disk.environment.to_s
      #raise "The disk is in another machine role" unless @global.role.to_s == disk.role.to_s
      
      disk
    end
  
      
  end
end