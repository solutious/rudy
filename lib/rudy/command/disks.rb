
module Rudy
class Disks
  include Rudy::Huxtable
  extend Rudy::MetaData
  
  
  def self.get(rname)
    Rudy::Disk.from_hash(super(rname)) # Returns nil if empty
  end
  
  def self.list
    
  end
  
end
end


__END__
module Rudy
  class Disks
    include Rudy::Huxtable
    
    
    def list(opts={})
      opts = {
        :all => false
      }.merge(opts)
      disk = find_disk(opts[:disk] || opts[:path]) || create_disk_from_opts(opts)
      query = opts[:all] ? disk.to_query([], [:zone, :environment, :role, :position, :path]) : disk.to_query
      items = execute_query(query)
    end
    
    
    def create(opts={})
      disk = create_disk_from_opts(opts)
      switch_user(:root)
      
      raise "#{disk.path} is already defined for that machine" if is_defined?(disk)
      raise "Device #{disk.device} is already defined for that machine" if device_used?(disk)
      raise "No size given" unless disk.size.kind_of?(Integer)
      raise "No path defined" if disk.path.nil?
      raise "Not enough info (#{disk.name})" unless disk.valid?

      begin

        rvolumes = Rudy::Volumes.new(opts)
        vol = rvolumes.create(disk.size, disk.zone)
        disk.awsid = vol.awsid        
        save(disk)
        
      rescue => ex
        @logger.puts "Error creating #{disk.name}: #{ex.message}".color(:red)
        @logger.puts ex.backtrace if debug?
        if vol
          @logger.puts "Destroying Volume #{vol.awsid}...".color(:red)
          destroy(disk)
        end
        return
      end
      
      disk
    end
    
    def attach(disk, machine=nil)
      disk_obj = find_disk(disk)
      
      #if instance && @ec2.instances.attached_volume?(instance.awsid, disk_obj.device)
      #  raise "Skipping disk for #{disk_obj.path} (device #{disk_obj.device} is in use)"
      #
      #end
    end
    
    def destroy(disk, instance=nil)
      disk_obj = find_disk(disk)
      raise "Disk #{disk} cannot be found" unless disk_obj
      is_mounted = is_mounted?(disk_obj)
      is_attached = is_attached?(disk_obj)
      is_available = @volumes.attached?(disk_obj.awsid)
      raise "Disk is in use (unmount it or use force)" if is_mounted && !@@global.force
      raise "Disk is attached (unattach it or use force)" if is_attached && !@@global.force
      
      begin
        
        if @@global.force 
          unmount(instance, disk_obj) if is_mounted
          @volumes.detach(disk_obj.awsid) if is_attached
          @volumes.destroy(disk_obj.awsid)
        end
        
        
        if disk_obj.awsid && !disk_obj.awsid.empty?
          
        end
        
      rescue => ex
        puts "Error while detaching volume #{disk_obj.awsid}: #{ex.message}"
        puts ex.backtrace if debug?
        puts "Continuing..."
      ensure
        puts "Deleteing metadata for #{disk_obj.name}"
        @sdb.destroy(Rudy::DOMAIN, disk_obj.name)
      end
    end
    
    
    
    # TODO: These are broken! They don't even look at rtype!
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
      disk = @sdb.get_attributes(Rudy::DOMAIN, name)
      return nil unless disk && disk.is_a?(Hash) && !disk.empty?
      Rudy::MetaData::Disk.from_hash(disk) || nil
    end

    def save(disk)
      @sdb.store(Rudy::DOMAIN, disk.name, disk.to_hash, :replace)
    end

    def is_defined?(disk)
      # We don't care about the path, but we do care about the device
      # which is not part of the disk's name. 
      disk_obj = find_disk(disk)
      raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk_obj
      query = disk_obj.to_query
      !(@sdb.query_with_attributes(Rudy::DOMAIN, query) || {}).empty?
    end
    
    def is_mounted?(disk)
      disk_obj = find_disk(disk)
      raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk_obj
    end
    
    def device_used?(disk)
      disk_obj = find_disk(disk)
      raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk_obj
      # We don't care about the path, but we do care about the device
      # which is not part of the disk's name. 
      query = disk.to_query(:device, :path)
      !(@sdb.query_with_attributes(Rudy::DOMAIN, query) || {}).empty?
    end
    
    
    # * +disk+ is a disk name (disk-zone-...), a path, or a Rudy::MetaData::Disk object
    # An exception is raised in the following cases:
    # * The disk belongs to a different environment or role than what's in @@globals. 
    # Returns the disk object or false if not found.
    def find_disk(disk)
      return false unless disk
      return disk if disk.is_a?(Rudy::MetaData::Disk)
      
      disc_obj = nil
      
      # If a disk name was supplied, the user knows what she's looking for.
      # If we don't find it, we can throw an error.
      if Rudy.is_id?(:disk, disk)
        disc_obj = get(disk)
      
      # Otherwise we assume it's a path
      else
        disc_obj = find_from_path(disk)
      end
      
      # TODO: This used to throw an exception. Some users of this method may need to throw their own.
      return false unless disc_obj

      # If a user specifies a disk that doesn't match the global 
      # values for environment and role, we need to throw an error. 
      unless @@global.environment.to_s == disc_obj.environment.to_s
        raise "The disk is in another machine environment" 
      end
      unless @@global.role.to_s == disc_obj.role.to_s
        raise "The disk is in another machine role"
      end
      
      disc_obj
    end
    
    
    
  private
    
    def execute_query(query)
      items = @sdb.query_with_attributes(Rudy::DOMAIN, query)
      return nil if !items || items.empty?
      clean_items = {}
      items.flatten.each do |disk|
        next unless disk.is_a?(Hash)
        name = disk.delete("Name")
        clean_items[name] = Rudy::MetaData::Disk.from_hash(disk)
      end
      clean_items
    end
    
    
    def create_disk_from_opts(opts)
      disk = Rudy::MetaData::Disk.new
      [:region, :zone, :environment, :role, :position].each do |n|
        disk.send("#{n}=", @@global.send(n)) if @@global.send(n)
      end

      [:path, :device, :size].each do |n|
        disk.send("#{n}=", opts[n]) if opts[n]
      end
      
      disk
    end
    
      
  end
end



__END__


# TODO: This is a fresh copy paster. 
#def restore(machine, opts)
#  disk = find_disk(opts[:disk] || opts[:path])
#  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
#  disk_routine.each_pair do |path,props|
#    from = props[:from] || "unknown"
#    unless from.to_s == "backup"
#      puts "Sorry! You can currently only restore from backup. Check your routines config."
#      next
#    end
#    
#    begin 
#      puts "Restoring disk for #{path}"
#      
#      zon = props[:zone] || @@global.zone
#      env = props[:environment] || @@global.environment
#      rol = props[:role] || @@global.role
#      pos = props[:position] || @@global.position
#      puts "Looking for backup from #{zon}-#{env}-#{rol}-#{pos}"
#      backup = find_most_recent_backup(zon, env, rol, pos, path)
#      
#      unless backup
#        puts "No backups found"
#        next
#      end
#      
#      puts "Found: #{backup.name}".bright
#      
#      disk = Rudy::MetaData::Disk.new
#      disk.path = path
#      [:region, :zone, :environment, :role, :position].each do |n|
#        disk.send("#{n}=", @@global.send(n)) if @@global.send(n)
#      end
#      
#      disk.device = props[:device]
#      size = (backup.size.to_i > props[:size].to_i) ? backup.size : props[:size]
#      disk.size = size.to_i
#      
#      
#      if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
#        puts "The disk #{disk.name} already exists."
#        puts "You probably need to define when to destroy the disk."
#        puts "Skipping..."
#        next
#      end
#
#      if @ec2.instances.attached_volume?(machine.awsid, disk.device)
#        puts "Skipping disk for #{disk.path} (device #{disk.device} is in use)"
#        next
#      end
#
#      # NOTE: It's important to use Caesars' hash syntax b/c the disk property
#      # "size" conflicts with Hash#size which is what we'll get if there's no 
#      # size defined. 
#      unless disk.size.kind_of?(Integer)
#        puts "Skipping disk for #{disk.path} (size not defined)"
#        next
#      end
#
#      if disk.path.nil?
#        puts "Skipping disk for #{disk.path} (no path defined)"
#        next
#      end
#
#      unless disk.valid?
#        puts "Skipping #{disk.name} (not enough info)"
#        next
#      end
#
#      puts "Creating volume... (from #{backup.awsid})".bright
#      volume = @ec2.volumes.create(disk.size, @@global.zone, backup.awsid)
#
#      puts "Attaching #{volume[:aws_id]} to #{machine.awsid}".bright
#      @ec2.volumes.attach(machine.awsid, volume[:aws_id], disk.device)
#      sleep 3
#
#      puts "Mounting #{disk.device} to #{disk.path}".bright
#      ssh_command machine.dns_name_public, keypairpath, @@global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
#
#      puts "Creating disk metadata for #{disk.name}"
#      disk.awsid = volume[:aws_id]
#      Rudy::MetaData::Disk.save(@sdb, disk)
#
#      sleep 1
#    rescue => ex
#      puts "There was an error restoring #{path}: #{ex.message}"
#      puts ex.backtrace if Drydock.debug?
#      #if disk
#      #  puts "Removing metadata for #{disk.name}"
#      #  Rudy::MetaData::Disk.destroy(@sdb, disk)
#      #end
#    end
#    puts
#  end
#
#
#end
#
#
#
#def device_to_path(machine, device)
#  # /dev/sdr            10321208    154232   9642688   2% /rilli/app
#  dfoutput = ssh_command(machine.dns_name_public, keypairpath, @@global.user, "df #{device} | tail -1").chomp
#  dfvals = dfoutput.scan(/(#{device}).+\s(.+?)$/).flatten  # ["/dev/sdr", "/rilli/app"]
#  dfvals.last
#end
