

module Rudy
  module CLI
    class Disks < Rudy::CLI::Base

      def disk
        puts "Disks".bright
        opts = {}
        [:all, :path, :device, :size].each do |v| 
          opts[v] = @option.send(v) if @option.respond_to?(v)
        end
        if @argv.diskname
          key = @argv.diskname =~ /^disk-/ ? :name : :path
          opts[key] = @argv.diskname
        end

        rdisks = Rudy::Disks.new(:config => @config, :global => @global)
        disks = rdisks.list(opts)
        raise "No disks." unless disks
        #rbacks = Rudy::Backups.new(:config => @config, :global => @global)
        disks.each_pair do |diskid, disk|
          #backups = rbacks.list_by_disk(disk, 2)
          print_disk(disk)
        end
      end
      def print_disk(disk, backups=[])
        return unless disk
        puts '-'*60
        puts "Disk: #{disk.name.bright}"
        puts disk.to_s
        puts "#{backups.size} most recent backups:", backups.collect { |back| "#{back.nice_time} (#{back.awsid})" }
        puts
      end
      
      def create_disk_valid?
        raise "No filesystem path specified" unless @option.path
        raise "No size specified" unless @option.size
        raise "No device specified" unless @option.device
        true
      end
      
      def create_disk
        puts "Creating Disk".bright
        exit unless Annoy.are_you_sure?(:low)
        opts = {}
        [:path, :device, :size, :group].each do |v| 
          opts[v] = @option.send(v) if @option.respond_to?(v)
        end
        opts[:id] = @option.awsid if @option.awsid
        opts[:id] &&= [opts[:id]].flatten
        
        @global.debug = true
        rmachines = Rudy::Machines.new(:config => @config, :global => @global)
        rmachines.list(opts).each_pair do |id,machine|
          rdisks = Rudy::Disks.new(:config => @config, :global => @global)
          disk = rdisks.create(machine, opts)
          print_disk(disk) if disk
        end
      end
      
      
      def destroy_disk_valid?
        raise "No disk specified" unless @argv.diskname

        true
      end
      
      def destroy_disk
        puts "Destroying Disk".bright
        exit unless Annoy.are_you_sure?(:medium)
        opts = {}
        if @argv.diskname
          key = @argv.diskname =~ /^disk-/ ? :name : :path
          opts[key] = @argv.diskname
        end
        
        # TODO: This is fucked! Store the machine info with the disk metadata.
        # Get all disks that match the request and destroy them.
        rmachines = Rudy::Machines.new(:config => @config, :global => @global)
        rmachines.list(opts).each_pair do |id,machine|
          rdisks = Rudy::Disks.new(:config => @config, :global => @global)
          rdisks.destroy(machine, opts)
        end
        
        puts "Done."
      end

      def attach_disk_valid?
        destroy_disk_valid?
        raise "There are no instances running in #{machine_group}" if !@instances || @instances.empty?
        true
      end
      
      def attach_disk
        puts "Attaching #{name}"
        switch_user("root")
        exit unless Annoy.are_you_sure?(:medium)
  
        machine = @instances.values.first  # AK! Assumes single machine
        
        execute_attach_disk(@disk, machine)

        puts
        ssh_command machine[:dns_name], keypairpath, @global.user, "df -h" # Display current mounts
        puts 

        puts "Done!"
      end



      
    end
  end
end


__END__

    



