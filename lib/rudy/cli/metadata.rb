

module Rudy
  module CLI
    class MetaData < Rudy::CLI::CommandBase
      
      
      def metadata
        more, less = [], []
        less = [:environment, :role, :zone, :region] if @option.all
        more += [:rtype, @option.otype] if @option.otype
        
        rdebug = Rudy::MetaData::Debug.new
        objlist = rdebug.list(more, less) || []
        objlist.each do |o|
          p o
        end
      end
      
      def metadata_delete_valid?
        raise "Must supply object ID" unless @argv.oid
        true
      end
      
      def metadata_delete
        rdebug = Rudy::MetaData::Debug.new
        unless @@global.quiet
          msg = "NOTE: This will delete only the metadata and "
          msg << "not the EC2 object (volume, instance, etc...)"
          puts msg
        end
        p rdebug.get( @argv.oid)
      end
    
    end
  end
end