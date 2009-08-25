

module Rudy
  module CLI
    class Backups < Rudy::CLI::CommandBase

      def get_backups
        # Rudy::Disks.list takes two optional args for adding or 
        # removing metadata attributes to modify the select query. 
        # When all is specified we want to find disks in every env
        # environment and role to we remove these attributes from
        # the select. 
        fields, less = { }, []
        if @option.all
          less = Rudy::Metadata::COMMON_FIELDS 
        else
          fields[:path] = @argv.first if @argv.first
        end
        
        dlist = Rudy::Backups.list(fields, less) || []
      end
      private :get_backups
      
      
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