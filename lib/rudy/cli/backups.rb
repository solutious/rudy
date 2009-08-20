

module Rudy
  module CLI
    class Backups < Rudy::CLI::CommandBase

      
      def backups
        more, less = {}, []
        less = [:environment, :role] if @option.all
        # We first get the disk metadata
        blist = Rudy::Backups.list(more, less) || []
        print_stobjects blist
      end
      
      def backups_wash
        dirt = (Rudy::Backups.list || []).select { |b| !b.snapshot_exists? }
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