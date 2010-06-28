

module Rudy
  module CLI
    class Disks < Rudy::CLI::CommandBase
      
      def disks
        disk_list = get_disks
        # If there are no disks currently, there could be backups
        # so we grab those to create a list of disks. 
        if @option.backups
          backups = Rudy::Backups.list(more, less) || []
          backups.each_with_index do |b, index|
            disk_list << b.disk
          end
        end
        # We go through the list of disks but we'll skip ones we've seen
        seen = []
        disk_list.each do |d|
          next if seen.member?(d.name)
          seen << d.name
          print_stobject d
          if @option.backups
            d.backups.each_with_index do |b, index|
              li '  %s' % b.name
              ##break if @option.all.nil? && index >= 2 # display only 3, unless all
            end
          end
        end
      end
      
      def disks_wash
        dirt = (get_disks || []).select { |d| !d.volume_exists? }
        if dirt.empty?
          li "Nothing to wash in #{current_machine_group}"
          return
        end
        
        li "The following disk metadata will be deleted:"
        li dirt.collect {|d| d.name }
        
        execute_check(:medium)

        dirt.each do |d|
          d.destroy(:force)
        end
        
      end
      
      def disks_create_valid?
        @mlist = Rudy::Machines.list
        raise "No machines" if @mlist.nil?
        
        raise "No path provided" unless @argv.first
        if !@@global.force && Rudy::Disks.exists?( @argv.first)
          raise "Disk exists" if Rudy::Disks.get(@argv.first).volume_attached?
        end
        raise "No size provided" unless @option.size
        
        true
      end
      
      def disks_create
        @mlist.each do |m|  
          li machine_separator(m.name, m.instid)
          rbox = Rudy::Routines::Handlers::RyeTools.create_box m
          rbox.stash = m
          disk = Rudy::Disk.new m.position, @argv.first
          disk.device = @option.device if @option.device
          disk.size = @option.size if @option.size
          disk.refresh! if disk.exists?  # We need the volume ID if available
          li "Creating disk: #{disk.name}"
          volumes = m.attached_volumes
          # don't include the current disk in the count. 
          volumes.reject! { |v| v.awsid == disk.volid } if disk.volid && disk.volume_attached?
          disk_index = volumes.size + 2
          Rudy::Routines::Handlers::Disks.create rbox, disk, disk_index
        end
      end
      
      def disks_destroy_valid?
        @dlist = Rudy::Disks.list
        raise "No disks" if @dlist.nil?
        
        @mlist = Rudy::Machines.list
        raise "No machines" if @mlist.nil? && !@@global.force
        
        raise "No path provided" unless @argv.first
        raise "Disk does not exist" unless Rudy::Disks.exists? @argv.first
        true
      end
      
      def disks_destroy
        execute_check(:medium)
        if !@mlist.empty?
          @mlist.each do |m|  
            rbox = Rudy::Routines::Handlers::RyeTools.create_box m
            rbox.stash = m
            disk = Rudy::Disk.new m.position, @argv.first
            li "Destroying disk: #{disk.name}"
            Rudy::Routines::Handlers::Disks.destroy rbox, disk, 0
          end
        else
          @dlist.each do |d|
            li "Working on #{d.name}"
            Rudy::Routines::Handlers::Disks.destroy nil, d, 0
          end
        end
      end
    end
  end
end