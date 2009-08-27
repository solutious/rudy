

module Rudy
  module CLI
    class Keypairs < Rudy::CLI::CommandBase
      
      
      def keypairs_add_valid?
        true
      end
      
      def keypairs_add 
        li current_group_name
      end
      
      def keypairs_valid?
        @pkey = current_user_keypairpath
        unless File.exists? @pkey
          raise "No private key file for #{current_machine_user} in #{current_group_name}"
        end
        true
      end
      
      def keypairs
        li Rudy::AWS::EC2::Keypairs.get(current_user_keypairname)
      end

      def keypairs_show_valid?
        keypairs_valid?
      end
            
      def keypairs_show
        content = File.read(@pkey)
        rkey = Rye::Key.new content
        li "# #{@pkey}"
        li content
        li rkey.public_key
      end
      
    end
  end
end

