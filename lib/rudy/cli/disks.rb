

module Rudy
  module CLI
    class Disks < Rudy::CLI::CommandBase

      
      def disks
        rdisk = Rudy::Disks.new
        rback = Rudy::Backups.new
        rdisk.list do |d|
          puts @@global.verbose > 0 ? d.inspect : d.dump(@@global.format)
          if @option.backups
            backups = rback.list || []
            backups[0,3].each do |b|
              puts '  %s' % b.name
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