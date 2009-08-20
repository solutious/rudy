

module Rudy
  module CLI
    class Disks < Rudy::CLI::CommandBase

      def get_disks
        # Rudy::Disks.list takes two optional args for adding or 
        # removing metadata attributes to modify the select query. 
        # When all is specified we want to find disks in every env
        # environment and role to we remove these attributes from
        # the select. 
        fields, less = {}, []
        less = Rudy::Metadata::COMMON_FIELDS if @option.all
        
        dlist = Rudy::Disks.list(fields, less) || []
      end
      private :get_disks
      
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
              puts '  %s' % b.name
              ##break if @option.all.nil? && index >= 2 # display only 3, unless all
            end
          end
        end
      end
      
      def disks_wash
        dirt = (get_disks || []).select { |d| !d.volume_exists? }
        if dirt.empty?
          puts "Nothing to wash in #{current_machine_group}"
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