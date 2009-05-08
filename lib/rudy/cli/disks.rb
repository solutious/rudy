

module Rudy
  module CLI
    class Disks < Rudy::CLI::CommandBase

      
      def disks
        rdisk = Rudy::Disks.new
        rback = Rudy::Backups.new
        disk_list = rdisk.list || []
        if @option.backups
          backups = rback.list || []
          backups.each_with_index do |b, index|
            disk_list << b.disk
          end
        end
        seen = []
        disk_list.each do |d|
          next if seen.member?(d.name)
          seen << d.name
          puts @@global.verbose > 0 ? d.inspect : d.dump(@@global.format)
          if @option.backups
            backups = rback.list(nil, nil, {}) || []
            backups.each_with_index do |b, index|
              puts '  %s' % b.name
              break if @option.all.nil? && index >= 2
            end
          end
        end
      end
      
      def disks_wash
        rdisk = Rudy::Disks.new
        dirt = (rdisk.list || [])#.select { |d| d.available? }
        if dirt.empty?
          puts "Nothing to wash in #{rdisk.current_machine_group}"
          return
        end
        
        puts "The following disk metadata will be deleted:"
        puts dirt.collect {|d| d.name }
        execute_check(:medium)

        dirt.each do |d|
          d.destroy(:force)
        end
        
      end
      
    end
  end
end