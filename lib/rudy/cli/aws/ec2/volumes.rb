

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Volumes < Rudy::CLI::Base
    
      
    def volumes_create_valid?
      raise "You must supply a volume size. See rudy volume -h" unless @option.size
      raise "You must supply a zone." unless @@global.zone
      true
    end
    def volumes_create
      puts "Create Volume".bright
      
      puts "Creating #{@option.size}GB volume in #{@@global.zone}"
      exit unless Annoy.are_you_sure?(:medium)
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      vol = rvol.create(@option.size, @@global.zone, @option.snapshot)
      
      puts vol.to_s
    end


    def destroy_volumes_valid?
      raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid      
      true
    end
    
    def destroy_volumes
      puts "Destroy Volume".bright
      
      @rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      
      @volume = @rvol.get(@argv.volid)
      
      raise "Volume #{@argv.volid} does not exist" unless @volume
      
      raise "Volume #{@argv.volid} is still in-use" if @volume.in_use?
      raise "Volume #{@argv.volid} is still attached" if @volume.attached?
      raise "Volume #{@argv.volid} is not available (#{@volume.state})" unless @volume.available?
      
      puts "Destroying #{@volume.awsid}"
      exit unless Annoy.are_you_sure?(:medium)
      
      ret = @rvol.destroy(@volume.awsid)
      raise "Failed" unless ret
      
      vol = @rvol.get(@volume.awsid)
      
      puts vol.to_s
    end
    
    
    #def volumes_attach_valid?
    #  raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid
    #  raise "You must supply an instance ID. See rudy volume -h" unless @argv.instid
    #  
    #  @rvol = Rudy::Volumes.new
    #  @rmach = Rudy::Machines.new
    #  raise "Volume #{@argv.volid} does not exist" unless @rvol.exists?(@argv.volid)
    #  raise "Instance #{@argv.instid} does not exist" unless @rmach.exists?(@argv.instid)
    #  
    #  true
    #end
    #def volumes_attach
    #  puts "Attach Volume".bright
    #  
    #  @option.device ||= "/dev/sdh"
    #  
    #  puts "Attaching #{@argv.volid} to #{@argv.instid} on #{@option.device}"
    #  exit unless Annoy.are_you_sure?(:low)
    #  
    #  ret = @rvol.attach(@argv.volid, @argv.instid, @option.device)
    #  raise "Attach failed" unless ret
    #  volume = @rvol.get(@argv.volid)
    #  puts volume.to_s
    #end
    #
    #def volumes_detach_valid?
    #  raise "You must supply a volume ID. See rudy volume -h" unless @argv.volid
    #  
    #  @rvol = Rudy::Volumes.new
    #  
    #  @volume = @rvol.get(@argv.volid)
    #  
    #  raise "Volume #{@argv.volid} does not exist" unless @volume
    #  
    #  #raise "Volume #{@argv.volid} is in use" unless @volume.in_use?
    #  raise "Volume #{@argv.volid} is not attached" unless @volume.attached?
    #  
    #  true
    #end
    #def volumes_detach
    #  puts "Detach Volume".bright
    #  
    #  puts "Detaching #{@volume.awsid} from #{@volume.instid}"
    #  exit unless Annoy.are_you_sure?(:low)
    #  
    #  ret = @rvol.detach(@volume.awsid)
    #  raise "Detach failed" unless ret
    #  volume = @rvol.get(@volume.awsid)
    #  puts volume.to_s
    #end
    
    
    def volumes
      puts "Volumes".bright
      
      rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey)
      volumes = rvol.list || []
      volumes.each do |volume|
        puts '-'*60
        puts volume.to_s
      end
      puts "No volumes" if volumes.empty?
    end
    
  end

end; end
end; end
