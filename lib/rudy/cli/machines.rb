

module Rudy::CLI
  class Machines < Rudy::CLI::Base
    
    def connect
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @option.awsid if @option.awsid
      opts[:id] &&= [opts[:id]].flatten
      opts[:print] = @option.print if @option.print
      
      if @argv.cmd
        opts[:cmd] = [@argv.cmd].flatten.join(' ')
        exit unless Annoy.are_you_sure?(:low)
      end
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.connect(opts)
    end
    
    def copy_valid?
      raise "You must supply a source and a target. See rudy #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      true
    end
    def copy
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @option.awsid if @option.awsid
      opts[:id] &&= [opts[:id]].flatten
      opts[:print] = @option.print if @option.print
      opts[:recursive] = @option.recursive if @option.recursive
      opts[:preserve] = @option.preserve if @option.preserve
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
      
      opts[:task] = :download if @alias == 'download' || @option.download
      opts[:task] = :upload if @alias == 'upload'
      opts[:task] ||= :upload
      
      exit unless @option.print || Annoy.are_you_sure?(:low)
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.copy(opts)
    end
    
    def shutdown_valid?
      raise "Cannot specify both instance ID and group name" if @argv.awsid && @option.group
      raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
      true
    end
    def shutdown
      puts "Shutting down a machine group".bright
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      msg = opts[:id] ? "instances: #{opts[:id].join(', ')}" : (opts[:group] ? "group: #{opts[:group]}" : '')
      puts "Shutting down #{msg}".bright
      puts "This command also affects the volumes attached to the instances! (according to your routines config)"
      exit unless Annoy.are_you_sure?(:high)        # TODO: Check if instances are running before this
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.shutdown(opts)
    end
    
    
    def status_valid?
      true
    end
    def status
      puts "Machine Status".bright
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:state] = @option.state if @option.state
      
      # A nil value forces the @ec2.instances.list to return all instances
      opts[:state] = nil if @option.all
      
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.status(opts)
    end
    
    
    def startup_valid?
      true
    end
    def startup
      puts "Starting a machine group".bright
      opts = {}
      opts[:ami] = @option.image if @option.image
      opts[:group] = @option.group if @option.group
      exit unless Annoy.are_you_sure?
      
      rmachines = Rudy::Machines.new(:config => @config, :global => @global)
      rdisks = Rudy::Disks.new(:config => @config, :global => @global)
      
      instances = rmachines.startup(opts)
      instances.each do |inst|
        rdisks.create_disk(inst)
      end
      
      puts "Done!"
    end

    def restart_valid?
      shutdown_valid?
    end
    def restart
      puts "Restarting #{machine_group}: #{@list.keys.join(', ')}".bright
      switch_user("root")
      exit unless Annoy.are_you_sure?(:medium)
      
      @list.each do |id, inst|
        execute_routines(@list.values, :restart, :before)
      end
      
      puts "Restarting instances: #{@list.keys.join(', ')}".bright
      @ec2.instances.restart @list.keys
      sleep 10 # Wait for state to change and SSH to shutdown
      
      @list.keys.each do |id|
        wait_for_machine(id)
      end
      
      execute_disk_routines(@list.values, :restart)
      
      @list.each do |id, inst|
        execute_routines(@list.values, :restart, :after)
      end
      
      puts "Done!"
    end
    
    

    
  end
end


