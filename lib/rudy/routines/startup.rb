

module Rudy
  module Routines
    class Startup < Rudy::Routines::Base
      

      
      def startup(opts={})
        # NOTE: Most of this is working as Rudy::Machines#create
        
        routine = fetch_routine(:startup)

          routine.disks.each_pair do |action,disks|

            unless @rdisks.respond_to?(action)
              @logger.puts("Skipping unknown action: #{action}").color(:blue)
              next
            end

            disks.each_pair do |path,props|
              props[:path] = path
              puts path
              begin
                @rdisks.send(action, instance, props)
              rescue => ex
                @logger.puts "Continuing..."
              end
            end
          end

          instances_with_dns << instance



        end

        instances_with_dns
      end


    end
  end
end