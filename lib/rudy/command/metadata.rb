

module Rudy
  module Command
    class Metadata < Rudy::Command::Base
      
      
      # Print Rudy's metadata to STDOUT
      def metadata(instances=[])
        puts group_metadata.keys
        #query = "['instances' = '#{instances.first}'] union ['group' = '#{machine}']"
        #
        # p @sdb.get_attributes(RUDY_DOMAIN, "instances_#{machine}")
        # p @sdb.query(RUDY_DOMAIN, query)
      end
      
      def destroy_metadata_valid?
        false
      end
      
      def destroy_metadata
        @sdb.domains.destroy(RUDY_DOMAIN)
      end
      
      def setup
        unless File.exists?(RUDY_CONFIG_DIR)
          puts "Creating #{RUDY_CONFIG_DIR}"
          Dir.mkdir(RUDY_CONFIG_DIR, 0700)
        end
        
        
        check_environment
        
        puts "Creating SimpleDB domain called #{RUDY_DOMAIN}"
        #@sdb.domains.create(RUDY_DOMAIN)
      end
      
      def info
        domains = @sdb.domains.list[:domains]
        puts "Domains: #{domains.join(", ")}"
      end
      
    private
      def check_environment
        raise "No Amazon keys provided!" unless has_keys?
        raise "No SSH keypairs provided!" unless has_keypairs?
        true
      end
        
    end
  end
end

