

module Rudy
  module CLI
    class Domains < Rudy::CLI::Base
      
      
      def domains
        puts "Domains".bright, $/
        
        rdom = Rudy::Domains.new(:config => @config, :global => @global)
        puts rdom.list
      end
      
    end
  end
end