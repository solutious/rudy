

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
        @sdb.domains.destroy(RUDY_DOMAIN)
      end
      
      # TODO: WHERE TO CREATE DOMAIN???????????????????????????
      
      def create_domain
        puts "Creating SimpleDB Domain called #{RUDY_DOMAIN}".bright
        rudy = Rudy::Manager.new(:config => @config, :global => @global)
        rudy.create_domain
        rudy.info
      end
      
      def info
        puts "Rudy Manager".bright
        rudy = Rudy::Manager.new(:config => @config, :global => @global)
        doms = rudy.domains
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

