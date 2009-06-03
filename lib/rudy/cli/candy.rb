
module Rudy
  module CLI
    class Candy < Rudy::CLI::CommandBase
      
      def open
        rmach = Rudy::Machines.new
        machines = rmach.list
        
        if machines
          `open http://#{machines.first.dns_public}`
        else
          puts "No machines"
        end
      end
      
    end
  end
end