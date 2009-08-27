

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
          li "Nothing to wash in #{current_machine_group}"
          return
        end
        
        li "The following backup metadata will be deleted:"
        li dirt.collect {|b| b.name }
        
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
          li "Creating backup for #{d.name}"
          back = d.archive
          li back
        end
      end
      
    end
  end
end