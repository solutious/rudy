

module Rudy
  module CLI
    class Networks < Rudy::CLI::CommandBase
      
      def networks
        name = current_group_name
        Rudy::AWS::EC2::Groups.list(name).each do |group|
          puts @@global.verbose > 0 ? group.inspect : group.dump(@@global.format)
        end
      end
      
      def update_networks
        Rudy::Routines::Handlers::Group.authorize rescue nil
      end
      
    end
    
  end
end