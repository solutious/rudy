

module Rudy
  module CLI
    class Keypairs < Rudy::CLI::CommandBase
      
      
      def keypairs_add_valid?
        true
      end
      
      def keypairs_add 
        puts current_group_name
      end
      
      def keypairs_valid?
        @pkey = current_user_keypairpath
        unless File.exists? @pkey
          raise "No private key configured for #{current_machine_user} in #{current_group_name}"
        end
        true
      end
      
      def keypairs
        puts @pkey
      end

      def keypairs_show_valid?
        keypairs_valid?
      end
            
      def keypairs_show
        puts "# #{@pkey}"
        puts File.read(@pkey)
      end
      
    end
  end
end

