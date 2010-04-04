

module Rudy::AWS
  
  module EC2
    
    class Address < Storable
      field :ipaddress => String
      field :instid => String
      
      def liner_note
        info = self.associated? ? @instid : "available"
        "%s (%s)" % [@ipaddress.to_s.bright, info]
      end
      
      def to_s(with_titles=false)
        liner_note
      end
      
      def associated?
        !@instid.nil? && !@instid.empty?
      end
    end
  
    module Addresses
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
  
      def create
        ret = @@ec2.allocate_address
        return false unless ret && ret['publicIp']
        address = Rudy::AWS::EC2::Address.new
        address.ipaddress = ret['publicIp']
        address
      end

      def destroy(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        raise UnknownAddress unless exists?(address)
        
        opts ={
          :public_ip => address || raise("No public IP address supplied")
        }
        ret = @@ec2.release_address(opts)
        (ret && ret['return'] == 'true')
      end


      # Associate an elastic IP to an instance
      def associate(address, instance)
        raise NoInstanceID unless instance
        raise NoAddress unless address
        
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        instance = instance.awsid if instance.is_a?(Rudy::AWS::EC2::Instance)
        raise UnknownAddress, address unless exists?(address)
        raise AddressAssociated, address if associated?(address)
        
        opts ={
          :instance_id => instance,
          :public_ip => address
        }
        ret = @@ec2.associate_address(opts)
        (ret && ret['return'] == 'true')
      end

      # Disssociate an elastic IP from an instance
      def disassociate(address)
        raise NoAddress unless address
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        instance = instance.awsid if instance.is_a?(Rudy::AWS::EC2::Instance)
        raise UnknownAddress unless exists?(address)
        raise AddressNotAssociated unless associated?(address)
        
        opts ={
          :public_ip => address
        }
        ret = @@ec2.disassociate_address(opts)
        (ret && ret['return'] == 'true')
      end



      # Returns a Array of Rudy::AWS::EC2::Address objects. 
      def list(addresses=[])
        addresses = list_as_hash(addresses)
        addresses &&= addresses.values
        addresses
      end
    
      # Returns a Hash of Rudy::AWS::EC2::Address objects. The key of the IP address.
      def list_as_hash(addresses=[])
        addresses ||= []
        addresses = [addresses].flatten.compact
        alist = @@ec2.describe_addresses(:addresses=> addresses)
        
        return nil unless alist['addressesSet'].is_a?(Hash)
      
        addresses = {}
        alist['addressesSet']['item'].each do |address|
          address = Addresses.from_hash(address)
          addresses[address.ipaddress] = address
        end
        addresses = nil if addresses.empty?
        addresses
      end
    
    
      def any?
        !list_as_hash.nil?
      end
      
      def get(address)
        raise "Address cannot be nil" if address.nil?
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        (list(address) || []).first
      end
      
      def self.from_hash(h)
        # requestId: 5ebcad80-eed9-4221-86f6-8d19d7acffe4
        # addressesSet: 
        #   item: 
        #   - publicIp: 75.101.137.7
        #     instanceId:
        address = Rudy::AWS::EC2::Address.new
        address.ipaddress = h['publicIp']
        address.instid = h['instanceId'] if h['instanceId'] && !h['instanceId'].empty?
        address
      end
    
    
      # +address+ is an IP address or Rudy::AWS::EC2::Address object
      # Returns true if the given address is assigned to the current account
      def exists?(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        (list || []).each do |a|
          return true if a.ipaddress == address
        end
        false
      end
    
      # +address+ is an IP address or Rudy::AWS::EC2::Address object
      # Returns true if the given address is associated to an instance
      def associated?(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        (list || []).each do |a|
          return true if a.ipaddress == address && a.instid
        end
        false
      end
    end
    
  end
end


