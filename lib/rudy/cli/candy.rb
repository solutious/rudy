
module Rudy
  module CLI
    class Candy < Rudy::CLI::CommandBase
      
      def open
        machines = Rudy::Machines.list
        
        if machines
          `open http://#{machines.first.dns_public}`
        else
          li "No machines"
        end
      end

    end
  end
end