

module Rudy
  module CLI
    class Metadata < Rudy::CLI::CommandBase
      
      def metadata_valid?
        @option.rtype ||= 'm'
        @metaobj = Rudy::Metadata.get_rclass @option.rtype
        true
      end
      
      def metadata
        more, less = {}, []
        less = [:environment, :role, :zone, :region, :position] if @option.all

        objlist = @metaobj.list(more, less) || []
        objlist.each do |o|
          puts "#{o}: " << o.inspect
        end
      end
      
      def metadata_delete_valid?
        raise "Must supply object ID" unless @argv.oid
        raise UnknownObject, @argv.oid unless Rudy::Metadata.exists? @argv.oid
        true
      end
      
      def metadata_delete

        unless @@global.quiet
          msg = "NOTE: This will delete only the metadata and "
          msg << "not the EC2 object (volume, instance, etc...)"
          puts msg
        end
        
        execute_check(:medium)
        
        Rudy::Metadata.destroy @argv.oid
      end
    
    end
  end
end