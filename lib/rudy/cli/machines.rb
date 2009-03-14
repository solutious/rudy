

module Rudy
  module CLI
    class Machines < Rudy::CLI::Base
      

      def shutdown_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        raise "Cannot specify both instance ID and group name" if @argv.awsid && @option.group
        raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        
        true
      end
      
      def shutdown
        puts "Shutting down #{@option.group}: #{@list.keys.join(', ')}".att(:bright)
        puts "This command also affects the volumes attached to the instances! (according to your routines config)"
        exit unless are_you_sure?(5)
        @option.group ||= machine_group
        rudy = Rudy::Machines.new(:config => @config)
        opts = {}
        opts[:group] = @option.group if @option.group
        opts[:id] = @argv.awsid if @argv.awsid
        rudy.shutdown(opts)
      end
      
      def shutdown2
        puts "Shutting down #{machine_group}: #{@list.keys.join(', ')}".att(:bright)
        switch_user("root")
        puts "This command also affects the volumes attached to the instances! (according to your routines config)"
        exit unless are_you_sure?(5)
        
        execute_routines(@list.values, :shutdown, :before)
        
        execute_disk_routines(@list.values, :shutdown)
        
        
        puts $/, "Terminating instances...".att(:bright), $/
        
        @ec2.instances.destroy @list.keys
        sleep 5
        
        execute_routines(@list.values, :shutdown, :after)
        
        puts "Done!"
      end
      
      def startup_valid?
        #rig = @ec2.instances.list(machine_group)
        #raise "There is already an instance running in #{machine_group}" if rig && !rig.empty?
        #raise "No SSH key provided for #{keypairname}!" unless has_keypair?
        true
      end
      def startup
        puts "Starting a machine in #{machine_group}".att(:bright)
        switch_user("root")
        exit unless are_you_sure?(3)
        
        #execute_routines([], :startup, :before_local)
        
        @option.image ||= machine_image
        
        puts "using AMI: #{@option.image}"
        
        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        y instances
        inst = instances.first
        
        if @option.address ||= machine_address
          puts "Associating #{@option.address} to #{inst[:aws_instance_id]}"
          @ec2.addresses.associate(inst[:aws_instance_id], @option.address)
        end
        
        wait_for_machine(inst[:aws_instance_id])
        inst = @ec2.instances.get(inst[:aws_instance_id])
        
        #inst = @ec2.instances.list(machine_group).values
        
        execute_disk_routines(inst, :startup)
        execute_routines(inst, :startup, :after)
        
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
      
      
      def status_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @option.group ||= machine_group
        @option.state ||= :running
        
        @list = @ec2.instances.list_by_group(@option.group, @option.state)

        raise "No machines running in #{@option.group}" unless @list && !@list.empty?
        true
      end
      def status
        puts "Status for #{@option.group} (state: #{@option.state})"

        @list.each_pair do |id, inst|
          puts '-'*60
          puts "Instance: #{id.att(:bright)} (AMI: #{inst.ami})"
          puts inst.to_s
        end
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
end


