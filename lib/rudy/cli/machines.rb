

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
        exit unless are_you_sure?(2)
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
      
      exit unless are_you_sure?(2)
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.copy(opts)
    end
    
    def shutdown_valid?
      raise "Cannot specify both instance ID and group name" if @argv.awsid && @option.group
      raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
      true
    end
    def shutdown
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      msg = opts[:id] ? "instances: #{opts[:id].join(', ')}" : (opts[:group] ? "group: #{opts[:group]}" : '')
      puts "Shutting down #{msg}".att(:bright)
      puts "This command also affects the volumes attached to the instances! (according to your routines config)"
      exit unless are_you_sure?(5)        # TODO: Check if instances are running before this
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.shutdown(opts)
    end
    
    
    def status_valid?
      true
    end
    def status
      puts "Machine Status".att(:bright)
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
      puts "Starting a machine".att(:bright)
      opts = {}
      opts[:ami] = @option.image if @option.image
      opts[:group] = @option.group if @option.group
      exit unless are_you_sure?(3)
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.startup(opts)
      puts "Done!"
    end

    def restart_valid?
      shutdown_valid?
    end
    def restart
      puts "Restarting #{machine_group}: #{@list.keys.join(', ')}".att(:bright)
      switch_user("root")
      exit unless are_you_sure?(5)
      
      @list.each do |id, inst|
        execute_routines(@list.values, :restart, :before)
      end
      
      puts "Restarting instances: #{@list.keys.join(', ')}".att(:bright)
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
    
    

    
    def update_valid?
      raise "No EC2 .pem keys provided" unless has_pem_keys?
      raise "No SSH key provided for #{@global.user}!" unless has_keypair?
      raise "No SSH key provided for root!" unless has_keypair?(:root)
      
      @option.group ||= machine_group
      
      @scripts = %w[rudy-ec2-startup update-ec2-ami-tools randomize-root-password]
      @scripts.collect! {|script| File.join(RUDY_HOME, 'support', script) }
      @scripts.each do |script| 
        raise "Cannot find #{script}" unless File.exists?(script)
      end
      
      true
    end
    
    def update
      puts "Updating Rudy on machines in #{@option.group}"
      switch_user("root")
      
      exit unless are_you_sure?
      scp do |scp|
        @scripts.each do |script|
          puts "Uploading #{File.basename(script)}"
          scp.upload!(script, "/etc/init.d/")
        end
      end
      
      ssh do |session|
        @scripts.each do |script|
          session.exec!("chmod 700 /etc/init.d/#{File.basename(script)}")
        end
        
        puts "Installing Rudy (#{Rudy::VERSION})"
        session.exec!("mkdir -p /etc/ec2")
        session.exec!("gem sources -a http://gems.github.com")
        puts session.exec!("gem install --no-ri --no-rdoc rudy -v #{Rudy::VERSION}")
      end
    end
    
    
  end
end


