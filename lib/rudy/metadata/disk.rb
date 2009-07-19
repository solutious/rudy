

module Rudy
  class Disk < Storable 
    include Rudy::Metadata
    
    field :rtype
    field :awsid
    field :status
    field :instid

    field :path

    field :device
    field :size
    #field :backups => Array

    # Is the associated volume formatted? One of: true, false, [empty]. 
    # [empty] means we don't know and it's the default. 
    field :raw

    field :fstype
    field :mounted

    field :created

    def initialize(path, size=1, device='/dev/sdh', position=nil)
      super 'disk'
      @path, @size, @device = path, size, device

      @mounted = false

      now = Time.now.utc
      #datetime = Backup.format_timestamp(now).split(Rudy::DELIM)
      @created = now.to_i

      postprocess
    end

    def postprocess
      @size &&= @size.to_i
      @mounted = true if @mounted == "true"
    end
    
    def name
      sep = File::SEPARATOR
      if Rudy.sysinfo.os == :unix
        dirs = @path.split sep if @path && !@path.empty?
        unless @path == File::SEPARATOR
          dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
        end
        super(*dirs)
      else
        raise UnsupportedOS, "Disks are not available for #{Rudy.sysinfo.os}"
      end
    end
    
  end
end