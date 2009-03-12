

module Rudy
  module Command
    class Machines < Rudy::Command::Base
      

      def shutdown_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        raise "No machines running in #{machine_group}" unless @list
        
        raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        
        true
      end
      
      
      def shutdown
        puts "Shutting down #{machine_group}: #{@list.keys.join(', ')}"

        puts "This command will also destroy the volumes attached to the instances!"
        exit unless are_you_sure?(5)
        
        puts "Running shutdown routines..."
        execute_shutdown_routines(@list.values)
        
        #puts "Terminating instances..."
        #@ec2.instances.destroy @list.keys
        #sleep 5
        
        puts "Done!"
      end
      
      #def restart_valid?
      #  shutdown_valid?
      #end
      #def restart
      #  puts "Restarting #{machine_group}: #{@list.keys.join(', ')}"
      #  
      #  switch_user("root")
      #  
      #  exit unless are_you_sure?(5)
      #  
      #  puts "Running Restart before routines..."
      #  @list.each do |id, inst|
      #    execute_restart_routines(:before, inst)
      #  end
      #  
      #  #@ec2.instances.restart @list.keys
      #  #sleep 10 # Wait for state to change
      #  
      #  @list.keys.each do |id|
      #    #wait_for_machine(id)
      #  end
      #  
      #  puts "Running Startup routines..."
      #  @list.each do |id, inst|
      #    execute_startup_routines(inst)
      #  end
      #  
      #  puts "Done!"
      #end
      
      
      def start_valid?
        rig = @ec2.instances.list(machine_group)
        #raise "There is already an instance running in #{machine_group}" unless rig.empty?
        raise "No SSH key provided for #{keypairname}!" unless has_keypair?
        true
      end
      def start
        
        @option.image ||= machine_image
        
        @global.user = "root"
        
        puts "Starting a machine in #{machine_group}"
        
        exit unless are_you_sure?
        
        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        inst = instances.first
        id, state = inst[:aws_instance_id], inst[:aws_state]
        
        if @option.address ||= machine_address
          puts "Associating #{@option.address} to #{id}"
          @ec2.addresses.associate(id, @option.address)
        end
        
        wait_for_machine(id)
        
        
        puts "Running Startup routines..."
        execute_startup_routines(inst)
        
        puts "Done!"
      end

      
      def status_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        raise "No machines running in #{machine_group}" unless @list
        true
      end
      def status
        puts "There are no machines running in #{machine_group}" if @list.empty?
        @list.each_pair do |id, inst|
          print_instance inst
        end
      end
      
      
      def update_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @script = File.join(RUDY_HOME, 'support', 'rudy-ec2-startup')
        
        raise "Cannot find startup script" unless File.exists?(@script)
        
        exit unless are_you_sure?
        
        true
      end
      

      def update
        switch_user("root")
        
        scp do |scp|
          puts "Updating Rudy startup script (#{@script})"
          scp.upload!(@script, "/etc/init.d/") do |ch, name, sent, total|
            puts "#{name}: #{sent}/#{total}"
          end
        end
        
        ssh do |session|
          session.exec!("chmod 700 /etc/init.d/rudy-ec2-startup")
          puts "Installing Rudy (#{Rudy::VERSION})"
          puts session.exec!("gem sources -a http://gems.github.com")
          puts session.exec!("gem install --no-ri --no-rdoc solutious-rudy -v #{Rudy::VERSION}")
        end
      end
      
      
    end
  end
end


