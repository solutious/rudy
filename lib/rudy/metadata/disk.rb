

module Rudy
  module MetaData
    class Disk < Storable
      include Rudy::Huxtable
      
      
        # This is a flag used internally to specify that a volume has been
        # created for this disk, but not yet formated. 
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
      
      def init
        @backups = []
        @raw_volume = false
        @rtype = Disk.rtype
      end
      
      def name
        Disk.generate_name(@zone, @environment, @role, @position, @path)
      end
      
      def Disk.generate_name(zon, env, rol, pos, pat, sep=File::SEPARATOR)
        pos = pos.to_s.rjust 2, '0'
        dirs = pat.split sep if pat
        dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        ["disk", zon, env, rol, pos, *dirs].join(Rudy::DELIM)
      end
      
      def valid?
        @zone && @environment && @role && @position && @path && @size && @device
      end
      
      def is_mounted?
        
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


__END__

def format(instance)
  raise "No instance supplied" unless instance
  raise "Disk not valid" unless self.valid?

  begin
    puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
    ssh_command instance.dns_name_public, current_user_keypairpath, @@global.user, "mkfs.ext3 -F #{disk.device}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error formatting #{disk.path}: #{ex.message}"
  end
  true
end
def mount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Mounting #{disk.device} to #{disk.path}".bright
    ssh_command instance.dns_name_public, current_user_keypairpath, @@global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error mounting #{disk.path}: #{ex.message}"
  end
  true
end

def unmount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Unmounting #{disk.path}...".bright
    ssh_command instance.dns_name_public, current_user_keypairpath, global.user, "umount #{disk.path}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error unmounting #{disk.path}: #{ex.message}"
  end
  true
end