

module Rudy
  module MetaData
    class Machine < Storable
      
      @@rtype = 'machine'
      
      field :rtype
      field :awsid
      
      field :environment
      field :role
      field :path
      field :position
      
      field :zone
      field :region
      
      def initialize
        @rtype = @@rtype.to_s
      end
      
      def rtype
        @@rtype.to_s
      end
      
      def rtype=(val)
      end
      
      
    end
  end
end