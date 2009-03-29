

module Rudy::AWS
  
  class EC2
    
    class Address < Storable
      field :ipaddress
      field :instid
      def to_s
        msg = "Address: #{self.ipaddress}"
        msg << ", instance: #{self.instid}" if self.instid
      end
    end
  
    class Addresses
      include Rudy::AWS::ObjectBase
    
      # Returns a Array of Rudy::AWS::EC2::Address objects. 
      def list 
        addresses = list_as_hash
        addresses &&= addresses.values
        addresses
      end
    
      # Returns a Hash of Rudy::AWS::EC2::Address objects. The key of the IP address.
      def list_as_hash
        alist = @aws.describe_addresses || []
      
        return nil unless alist['addressesSet'].is_a?(Hash)
      
        addresses = {}
        alist['addressesSet']['item'].each do |address|
          address = Addresses.from_hash(address)
          addresses[address.ipaddress] = address
        end
        addresses
      end
    
    
      def any?
        !(list_as_hash || {}).empty?
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
    
      # Associate an elastic IP to an instance
      def associate(instance, address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        instance = instance.awsid if instance.is_a?(Rudy::AWS::EC2::Instance)
        raise "Not a valid address" unless valid?(address)
        opts ={
          :instance_id => instance || raise("No instance ID supplied"),
          :public_ip => address || raise("No public IP address supplied")
        }
        ret = @aws.associate_address(opts)
        (ret && ret['return'] == 'true')
      end
    
    
      def create
        ret = @aws.allocate_address
        return false unless ret && ret['publicIp']
        address = Rudy::AWS::EC2::Address.new
        address.ipaddress = ret['publicIp']
        address
      end
    
      def destroy(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        raise "Not a valid address" unless valid?(address)
        opts ={
          :public_ip => address || raise("No public IP address supplied")
        }
        ret = @aws.release_address(opts)
        (ret && ret['return'] == 'true')
      end
    
    
      # +address+ is an IP address or Rudy::AWS::EC2::Address object
      # Returns true if the given address is assigned to the current account
      def valid?(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        list.each do |a|
          return true if a.ipaddress == address
        end
        false
      end
    
      # +address+ is an IP address or Rudy::AWS::EC2::Address object
      # Returns true if the given address is associated to an instance
      def associated?(address)
        address = address.ipaddress if address.is_a?(Rudy::AWS::EC2::Address)
        list.each do |a|
          return true if a.ipaddress == address && a.instid
        end
        false
      end
    end
  end
end