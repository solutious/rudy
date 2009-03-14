

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
    
  private
    def process_filter_options(opts)
      opts = { :group => nil, :id => nil }.merge(opts)
      raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
      opts[:id] &&= [opts[:id]].flatten
      instances = opts[:id] ? @ec2.instances.list(opts[:id], :running) : @ec2.instances.list_by_group(opts[:group], :running)
      raise "No machines running" unless instances && !instances.empty?
      [opts, instances]
    end
    
  end
end