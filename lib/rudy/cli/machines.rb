

module Rudy::CLI
  class Machines < Rudy::CLI::Base
    

    def shutdown_valid?
      raise "Cannot specify both instance ID and group name" if @argv.awsid && @option.group
      raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
      true
    end
    def shutdown
      @option.group ||= machine_group
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] = [opts[:id]] if opts[:id] && !opts[:id].is_a?(Array)
      
      msg = opts[:id] ? "instances: #{opts[:id].join(', ')}" : "group: #{opts[:group]}"
      puts "Shutting down #{msg}".att(:bright)
      puts "This command also affects the volumes attached to the instances! (according to your routines config)"
      exit unless are_you_sure?(5)        
      
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.shutdown(opts)
    end
    
    def status_valid?
      @option.group ||= machine_group
      @option.state ||= :running
      true
    end
    def status
      puts "Status for #{@option.group} (state: #{@option.state})"
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] = [opts[:id]] if opts[:id] && !opts[:id].is_a?(Array)
      rudy = Rudy::Machines.new(:config => @config, :global => @global)
      rudy.status(opts)
    end
    
    def startup_valid?
      @option.image ||= machine_image
      @option.address ||= machine_address
      raise "No AMI supplied" unless @option.image
      true
    end
    def startup
      puts "Starting a machine in #{machine_group}".att(:bright)
      exit unless are_you_sure?(3)

      
      
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


