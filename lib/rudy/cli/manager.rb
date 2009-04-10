

module Rudy
  module CLI
    class Manager < Rudy::CLI::Base
      
      
      # Print Rudy's metadata to STDOUT
      def metadata
        group_metadata.each_pair do |n,h|
          puts n.bright
          puts h.inspect, ""
        end
      end
      
      def destroy_metadata_valid?
        false
      end
      
      def destroy_metadata
        @sdb.domains.destroy(Rudy::DOMAIN)
      end
      
      # TODO: WHERE TO CREATE DOMAIN???????????????????????????
      
      def create_domain
        puts "Creating SimpleDB Domain called #{Rudy::DOMAIN}".bright
        rmanager = Rudy::Manager.new(:config => @config, :global => @global)
        rmanager.create_domain(Rudy::DOMAIN)
        doms = rmanager.domains || []
        puts "Domains: #{doms.join(", ")}"
      end
      
      def info
        puts "Rudy Manager".bright
        rmanager = Rudy::Manager.new(:config => @config, :global => @global)
        doms = rmanager.domains
        puts "Domains: #{doms.join(", ")}"
      end
      
    private
      def check_environment
        raise "No Amazon keys provided!" unless has_keys?
        raise "No SSH keypairs provided!" unless has_keypair?
        true
      end
      
    end
  end
end

