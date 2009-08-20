
module Rudy::AWS
  module EC2
    
    class Zone < Storable
      
      field :name
      field :region
      field :state  
      
      def to_s(titles=false)
        [@name.bright, @region, @state].join '; '
      end

    end
    
    module Zones
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
      
      def list(*names)
        zones = list_as_hash(names)
        zones &&= zones.values
        zones
      end
      
      def list_as_hash(*names)
        names = names.flatten
        zlist = @@ec2.describe_availability_zones(:zone_name => names)
        return unless zlist['availabilityZoneInfo'].is_a?(Hash)
        zones = {}
        zlist['availabilityZoneInfo']['item'].each do |zhash| 
          zon = Zones.from_hash(zhash)
          zones[zon.name] = zon
        end
        zones = nil if zones.empty?
        zones
      end

      def self.from_hash(h)
        zone = Rudy::AWS::EC2::Zone.new
        zone.name = h['zoneName']
        zone.region = h['regionName']
        zone.state = h['zoneState']
        zone
      end
      
      def any?
        zones = list || []
        !zones.empty?
      end
      
      def get(name)
        zones = list(name) || []
        return if zones.empty?
        zones.first
      end
      
      def zone?(name)
        begin
          kp = get(name)
          kp.is_a?(Rudy::AWS::EC2::Zone)
        rescue => ex
          false
        end
      end
      
    end
    
  end
end


