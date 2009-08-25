

module Rudy
  module CLI
    class Backups < Rudy::CLI::CommandBase

      
      def backups
        blist = get_backups
        print_stobjects blist
      end
      
      def backups_wash
        dirt = (get_backups || []).select { |b| !b.snapshot_exists? }
        if dirt.empty?
          puts "Nothing to wash in #{current_machine_group}"
          return
        end
        
        puts "The following backup metadata will be deleted:"
        puts dirt.collect {|b| b.name }
        
        execute_check(:medium)

        dirt.each do |b|
          b.destroy
        end
        
      end
      
      def backups_create_valid?
        @dlist = Rudy::Disks.list
        raise "No disks" if @dlist.nil?
        raise "No path provided" unless @argv.first
        raise "Disk does not exist" unless Rudy::Disks.exists? @argv.first
        true
      end
      
      def backups_create
        @dlist.each do |d|
          puts "Creating backup for #{d.name}"
          back = d.archive
          puts back
        end
      end
      
    end
  end
end