

module Rudy
  module Routines
    class Shutdown < Rudy::Routines::Base
      
      def shutdown
        routine = fetch_routine(:shutdown)
        rmach = Rudy::Instances.new(:config => @config, :global => @global)
        rmach.destroy do
          @logger.puts $/, "Running BEFORE scripts...", $/
          #instances.each { |inst| @script_runner.execute(inst, :shutdown, :before) }

          @logger.puts $/, "Running DISK routines...", $/
          routine.disks.each_pair do |action,disks|

            unless @rdisks.respond_to?(action)
              @logger.puts("Skipping unknown action: #{action}").color(:blue)
              next
            end

            disks.each_pair do |path,props|
              props[:path] = path
              begin
                @rdisks.send(action, instance, props)
              rescue => ex
                @logger.puts ex.message
                @logger.puts "Continuing..."
                @logger.puts ex.backtrace if debug?
              end
            end
            
          end
        end
        
      end
      
    end
  end
end

      