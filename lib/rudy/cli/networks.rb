

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
      
      def local_networks
        ea = Rudy::Utils::external_ip_address || '' 
        ia = Rudy::Utils::internal_ip_address || ''
        if @global.quiet
          puts ia unless @option.external && !@option.internal
          puts ea unless @option.internal && !@option.external
        else
          puts "%10s: %s" % ['Internal', ia] unless @option.external && !@option.internal
          puts "%10s: %s" % ['External', ea] unless @option.internal && !@option.external
        end
        @global.quiet = true  # don't print elapsed time
      end
      
    end
    
  end
end