

module Rudy
  module Command
    class Metadata < Rudy::Command::Base
      
      
      # Print Rudy's metadata to STDOUT
      def metadata
        group_metadata.each_pair do |n,h|
          puts n.att(:bright)
          puts h.inspect, ""
        end
      end
      
      def destroy_metadata_valid?
        false
      end
      
      def destroy_metadata
        @sdb.domains.destroy(RUDY_DOMAIN)
      end
      
      
      
      def info
        domains = @sdb.domains.list[:domains]
        puts "Domains: #{domains.join(", ")}"
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

