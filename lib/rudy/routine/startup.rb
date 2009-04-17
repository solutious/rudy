

module Rudy; module Routine;

  class Startup < Rudy::Routines::Base
    
    def execute
      rmach = Rudy::Machines.new
      raise MachineGroupAlreadyRunning, current_machine_group if rmach.running?
      
        
      opts = {
        :min  => current_machine_count,
        :size => current_machine_size,
        :ami => current_machine_image,
        :group => current_machine_group
      }
      
      y opts
      exit
      unless (1..MAX_INSTANCES).member?(instance_count)
        raise "Instance count must be more than 0, less than #{MAX_INSTANCES}"
      end
      
      
      routine = fetch_routine_config(:startup)
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      #rinst.create(opts) do |instance|
      #  puts instance.awsid
      #end
    end

  end

end; end