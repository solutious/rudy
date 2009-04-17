

module Rudy
  module CLI
    class Machines < Rudy::CLI::CommandBase
      
      
      def machines
        rmach = Rudy::Machines.new
        rmach.list do |m|
          puts @@global.verbose > 0 ? m.inspect : m.dump(@@global.format)
        end
      end
      
      def machines_wash
        rmach = Rudy::Machines.new
        dirt = (rmach.list || []).select { |m| !m.running? }
        if dirt.empty?
          puts "Nothing to wash in #{rmach.current_machine_group}"
          return
        end
        
        puts "The following machine metadata will be deleted:"
        puts dirt.collect {|m| m.name }
        execute_check(:medium)
        
        dirt.each do |m|
          m.destroy
        end
        
      end
      
    end
  end
end