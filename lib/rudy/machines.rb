

module Rudy
  
  class Machines
    include Huxtable
      
    def shutdown(opts={})
      opts = { :group => nil, :id => nil }.merge(opts)
      raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
      opts[:id] = [opts[:id]] if opts[:id] && opts[:id].is_a?(Array)
             
      @instances = opts[:group] ? @ec2.instances.list_by_group(opts[:group]) : @ec2.instances.list(opts[:id])
      raise "No machines running" unless @instances && !@instances.empty?
      
      puts $/, "Running BEFORE scripts...".att(:bright), $/
      @instances.each { |machine| @script_runner.execute(machine, :shutdown, :before) }
      
      puts $/, "Terminating instances...".att(:bright), $/
      @ec2.instances.destroy @list.keys
      
      waiter(4, 32) do # This raises an exception if it times out
        #@ec2.instances.running?(@list.first)
        true
      end
      
      puts $/, "Running AFTER scripts...".att(:bright), $/
      @instances.each { |machine| @script_runner.execute(machine, :shutdown, :after) }

    end
       
  end
end