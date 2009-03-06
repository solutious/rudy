

module Rudy
  module Command
    class Machines < Rudy::Command::Base
      

      
      
      def restart_machines_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @list = @ec2.instances.list(machine_group)
        raise "No machines to restart in #{machine_group}" unless @list
        
        raise "I will not help you destroy production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        
        exit unless are_you_sure?(5)
        true
      end
      def restart_machines
        @list = @ec2.instances.list(machine_group)
        puts "Restarting #{machine_group}: #{@list.keys.join(', ')}"
        #@ec2.instances.restart @list.keys
        #sleep 5
        
        @list.keys.each do |id|
          wait_to_attach_disks(id)
        end
        
        puts "Done!"
      end
      
      
      def start_machines_valid?
        exit unless are_you_sure?  
        rig = @ec2.instances.list(machine_group)
        #raise "There is already an instance running in #{machine_group}" unless rig.empty?
        raise "No SSH key provided for #{keypairname}!" unless has_keypair?
        true
      end
      def start_machines
        
        @option.image ||= machine_image
        
        @global.user = "root"
        
        puts "Starting an instance in #{machine_group}"
        puts "with machine data:", machine_data.to_yaml

        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        inst = instances.first
        id, state = inst[:aws_instance_id], inst[:aws_state]
        
        if @option.address ||= machine_address
          puts "Associating #{@option.address} to #{id}"
          @ec2.addresses.associate(id, @option.address)
        end
        
        wait_to_attach_disks(id)
        
        puts "Done!"
      end

      
      def wait_to_attach_disks(id)
        
        print "Waiting for #{id} to become available"
        STDOUT.flush
        
        while @ec2.instances.pending?(id)
          sleep 2
          print '.'
          STDOUT.flush
        end
        
        machine = @ec2.instances.get(id)
        
        puts " It's up!\a\a\a" # with bells
        print "Waiting for SSH daemon at #{machine[:dns_name]}"
        while !Rudy::Utils.service_available?(machine[:dns_name], 22)
          print '.'
          STDOUT.flush
        end
        puts " It's up!"
        
        print "Looking for disk metadata for #{machine[:aws_availability_zone]}... "
        disks = Rudy::MetaData::Disk.list(@sdb, machine[:aws_availability_zone], @global.environment, @global.role, @global.position)
        
        if disks.empty?
          puts "None"
        else
          puts "#{disks.size} disk(s)."
          disks.each do |disk|
            
            do_dirty_disk_volume_deeds(disk, machine)
          end
        end
        
        puts
        ssh_command machine[:dns_name], keypairpath, @global.user, "df -h" # Display current mounts
        puts
      end
      
      
      def update_machines_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @script = File.join(RUDY_HOME, 'support', 'rudy-ec2-startup')
        
        raise "Cannot find startup script" unless File.exists?(@script)
        
        exit unless are_you_sure?
        
        true
      end
      

      def update_machines
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


