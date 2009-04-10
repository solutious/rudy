

module Rudy
  module Routines
    class Startup < Rudy::Routines::Base
      
      
      def startup(opts={})
        
        routine = fetch_routine(:startup)
        rdisks = Rudy::Disks.new(:config => @@config, :global => @@global)
        
        
        rmach = Rudy::Machines.new(:config => @@config, :global => @@global)
        
        # TODO: .list for debugging, .create for actual use
        instances = rmach.list(opts) do |instance| # Rudy::AWS::EC2::Instance objects
          puts '-'*60
          puts "Instance: #{instance.awsid.bright} (AMI: #{instance.ami})"
          puts instance.to_s
        
          @logger.puts("Running DISK routines")
          routine.disks.each_pair do |action,disks|
        
            unless rdisks.respond_to?(action)
              @logger.puts("Skipping unknown action: #{action}").color(:blue)
              next
            end
        
            disks.each_pair do |path,props|
              props[:path] = path
              puts path
              begin
                rdisks.send(action, instance, props)
              rescue => ex
                @logger.puts "Continuing..."
              end
            end
          end
        end
                
        instances
      end


    end
  end
end