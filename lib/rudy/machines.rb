

module Rudy
  
  class Machines
    include Huxtable
      
    
    
    def shutdown(opts={})
      opts, instances = process_filter_options(opts)

      @logger.puts $/, "Running BEFORE scripts...".att(:bright), $/
      instances.each { |inst| @script_runner.execute(inst, :shutdown, :before) }
      
      @logger.puts $/, "Terminating instances...".att(:bright), $/
      @ec2.instances.destroy instances.keys
      
      waiter(4, 10) do # This raises an exception if it times out
        @logger.puts "Waiting for #{instances.first} to terminate"
        !@ec2.instances.running?(instances.first)
      end
      
      @logger.puts $/, "Running AFTER scripts...".att(:bright), $/
      instances.each { |inst| @script_runner.execute(inst, :shutdown, :after) }
    end
       
    def status(opts={})
      opts, instances = process_filter_options(opts)
      instances.each_pair do |id, inst|
        puts '-'*60
        puts "Instance: #{id.att(:bright)} (AMI: #{inst.ami})"
        puts inst.to_s
      end
    end
    
    def start(opts={})
      opts = { :ami => nil, :group => nil, :user => nil, :keypair => nil, :address => nil }.merge(opts)
      puts "using AMI: #{ami}"
      
      instances = @ec2.instances.create(ami, group.to_s, File.basename(keypair), machine_data.to_yaml, @global.zone)
      y instances
      inst = instances.first
      
      if opts[:address]
        @logger.puts "Associating #{opts[:address]} to #{inst.awsid}"
        @ec2.addresses.associate(inst.awsid, opts[:address])
      end
      
      wait_for_machine(inst[:aws_instance_id])
      inst = @ec2.instances.get(inst[:aws_instance_id])
      
      #inst = @ec2.instances.list(machine_group).values
      
      execute_disk_routines(inst, :startup)
      execute_routines(inst, :startup, :after)
    end
    
  private
    def process_filter_options(opts)
      opts = { :group => nil, :id => nil }.merge(opts)
      raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
      opts[:id] &&= [opts[:id]].flatten
      instances = opts[:id] ? @ec2.instances.list(opts[:id], :running) : @ec2.instances.list_by_group(opts[:group], :running)
      raise "No machines running" unless instances && !instances.empty?
      [opts, instances]
    end
    def machine_data
      data = {
        # Give the machine an identity
        :zone => @global.zone,
        :environment => @global.environment,
        :role => @global.role,
        :position => @global.position,
        
        # Add hosts to the /etc/hosts file
        :hosts => {
          :dbmaster => "127.0.0.1",
        }
      } 
      data.to_hash
    end
    
  end
end