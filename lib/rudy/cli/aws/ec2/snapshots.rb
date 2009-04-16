

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Snapshots < Rudy::CLI::CommandBase
    
    def create_snapshots_valid?
      raise Drydock::ArgError.new('volume ID', @alias) unless @option.volume
      @rvol = Rudy::AWS::EC2::Volumes.new(@@global.accesskey, @@global.secretkey, @@global.region)
      @volume = @rvol.get(@argv.volid)
      raise "Volume #{@volume.awsid} does not exist" unless @volume
      true
    end
    def create_snapshots
      rsnap = Rudy::AWS::EC2::Snapshots.new(@@global.accesskey, @@global.secretkey, @@global.region)
      snap = execute_action { rsnap.create(@volume.awsid) }
      puts @@global.verbose > 0 ? snap.inspect : snap.dump(@@global.format)
    end
    
    def destroy_snapshots_valid?
      raise Drydock::ArgError.new('snapshot ID', @alias) unless @argv.snapid
      @rsnap = Rudy::AWS::EC2::Snapshots.new(@@global.accesskey, @@global.secretkey, @@global.region)
      @snap = @rsnap.get(@argv.snapid)
      raise "Snapshot #{@snap.awsid} does not exist" unless @snap
      true
    end
    def destroy_snapshots
      puts "Destroying: #{@snap.awsid}"
      execute_check(:medium)
      execute_action { @rsnap.destroy(@snap.awsid) }
      snapshots
    end
    
    def snapshots
      rsnap = Rudy::AWS::EC2::Snapshots.new(@@global.accesskey, @@global.secretkey, @@global.region)
      snaps = rsnap.list || []
      snaps.each do |snap|
        puts @@global.verbose > 0 ? snap.inspect : snap.dump(@@global.format)
      end
      puts "No snapshots" if snaps.empty?
    end
    
    
  end


end; end
end; end
