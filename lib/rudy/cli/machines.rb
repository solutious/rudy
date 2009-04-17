

module Rudy
  module CLI
    class Machines < Rudy::CLI::CommandBase
      
      
      def machines
        rmach = Rudy::Machines.new
        rmach.list.each do |m|
          puts @@global.verbose > 0 ? m.inspect : m.dump(@@global.format)
        end
      end

    end
  end
end