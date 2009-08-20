

module Rudy
  module CLI
    class Backups < Rudy::CLI::CommandBase

      def get_backups
        # Rudy::Disks.list takes two optional args for adding or 
        # removing metadata attributes to modify the select query. 
        # When all is specified we want to find disks in every env
        # environment and role to we remove these attributes from
        # the select. 
        fields, less = {}, []
        less = Rudy::Metadata::COMMON_FIELDS if @option.all
        
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
      
    end
  end
end