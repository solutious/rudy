

module Rudy
  module Routines
    class Base
      include Rudy::Huxtable
    
      # Examples:
      #
      # def before
      # end
      # def before_local
      # end
      # def svn
      # end
      #
      
      
      #
      #
      def execute
        raise "Override this method"
      end
      
      
      
      # We grab the appropriate routines config and check the paths
      # against those defined for the matching machine group. 
      # Disks that appear in a routine but not the machine will be
      # removed and a warning printed. Otherwise, the routines config
      # is merged on top of the machine config and that's what we return.
      def fetch_routine(action)
        raise "No configuration" unless @config
        raise "No globals" unless @global
        
        disk_definitions = @config.machines.find_deferred(@global.environment, @global.role, :disks)
        routine = @config.routines.find(@global.environment, @global.role, action)
        routine.disks.each_pair do |raction,disks|
          disks.each_pair do |path, props|
            routine.disks[raction][path] = disk_definitions[path].merge(props) if disk_definitions.has_key?(path)
            unless disk_definitions.has_key?(path)
              @logger.puts "#{path} is not defined. Check your #{action} routines config.".color(:red)
              routine.disks[raction].delete(path) 
            end
          end
        end
        routine
      end


      
    end
  end
end