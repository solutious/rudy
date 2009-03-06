# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 

module Rudy
  module Command
    class Instances < Rudy::Command::Base
      
      
      def restart_instances_valid?
        raise "No instance ID provided" if @argv.filter.nil?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        
        @list = @ec2.instances.list(machine_group)
        raise "#{@argv.filter} is not in the current machine group" unless @list.has_key?(@argv.filter)
        
        raise "I will not help you destroy production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        
        exit unless are_you_sure?(5)
        true
      end
      
      def restart_instances
        puts "Restarting #{@argv.filter}!"
        @ec2.instances.restart @argv.filter
      end
      
      def instances
        filter = @argv.first
        filter = machine_group if filter.nil? && !@option.all
        if instance_id?(filter)
          inst = @ec2.instances.get(filter)
          raise "The instance #{filter} does not exist" if inst.empty?
          list = {inst[:aws_instance_id] => inst}
        else
          raise "The security group #{filter} does not exist" if filter && !@ec2.groups.exists?(filter)
          list = @ec2.instances.list(filter)
          if list.empty? 
            msg = "There are no instances running" 
            msg << " in the group #{filter}" if filter
            raise msg
          end
        end
        
        list.each_pair do |id, inst|
          print_instance inst
        end
        
      end
      
      def destroy_instances_valid?
        filter = argv.first
        raise "No instance ID provided" if filter.nil?
        raise "I will not help you destroy production!" if @global.environment == "prod" || filter =~ /^prod/
        exit unless are_you_sure?
        true
      end
        
      def destroy_instances
        filter = argv.first

        if @ec2.groups.exists?(filter)
          list = @ec2.instances.list(filter)
          raise "The group #{filter} has no running instances" if list.empty?
          instance = list.keys.first
        else 
          instance = filter
        end
        puts "Destroying #{instance}!"
        @ec2.instances.destroy instance
      end

      def start_instances_valid?
        exit unless are_you_sure?  
        rig = @ec2.instances.list(machine_group)
        #raise "There is already an instance running in #{machine_group}" unless rig.empty?
        raise "No SSH key provided for #{keypairname}!" unless has_keypair?
        true
      end
        
      def start_instances
        
        @option.image ||= machine_image
        
        @global.user = "root"
        
        
        machine_data = {
          # Give the machine an identity
          :zone => @global.zone,
          :environment => @global.environment,
          :role => @global.role,
          :position => @global.position,
          
          # Add hosts to the /etc/hosts file
          :hosts => {
            :dbmaster => "127.0.0.1",
          },
          
          :userdata => {}
        } 
        
        users = @config.machinegroup.find_deferred(@global.environment, @global.role, :users) || {}
        
        # Populate userdata with settings from ~/.rudy
        unless users.empty?
          # Build a set of parameters for each user on the requested
          # machine. Set default values first and overwrite. (TODO)
          users.each_pair do |user,hash|
            machine_data[:userdata][user] = hash[:userdata].to_hash if hash[:userdata]
          end
        end
        puts "Starting an instance in #{machine_group}"
        puts "with machine data:", machine_data.to_yaml

        instances = @ec2.instances.create(@option.image, machine_group.to_s, File.basename(keypairpath), machine_data.to_yaml, @global.zone)
        inst = instances.first
        id, state = inst[:aws_instance_id], inst[:aws_state]
        
        if @option.address
          puts "Associating #{@option.address} to #{id}"
          @ec2.addresses.associate(id, @option.address)
        end
        
        print "Waiting for #{id} to become available"
        
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
        puts "Done!"
      end
      
    end
  end
end

