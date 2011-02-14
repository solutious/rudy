

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Snapshots < Rudy::CLI::CommandBase
    
    def create_snapshots_valid?
      raise Drydock::ArgError.new('volume ID', @alias) unless @option.volume
      @volume = Rudy::AWS::EC2::Volumes.get(@option.volume)
      !@volume.nil?
    end
    def create_snapshots
      snap = execute_action { Rudy::AWS::EC2::Snapshots.create(@volume.awsid) }
      print_stobject snap
    end
    
    def destroy_snapshots_valid?
      raise Drydock::ArgError.new('snapshot ID', @alias) unless @argv.snapid
      @snap = Rudy::AWS::EC2::Snapshots.get(@argv.snapid)
      raise "Snapshot #{@snap.awsid} does not exist" unless @snap
      true
    end
    def destroy_snapshots
      li "Destroying: #{@snap.awsid}"
      execute_check(:medium)
      execute_action { Rudy::AWS::EC2::Snapshots.destroy(@snap.awsid) }
    end
    
    def snapshots
      snaps = Rudy::AWS::EC2::Snapshots.list || []
      print_stobjects snaps
    end
    
    
  end


end; end
end; end
