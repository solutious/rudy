
module Rudy::AWS
  
  class EC2
    class UserData
      
    end
    
    class Images
      include Rudy::AWS::ObjectBase
      
      # Returns an array of hashes:
      # {:aws_architecture=>"i386", :aws_owner=>"105148267242", :aws_id=>"ami-6fe40dd5", 
      #  :aws_image_type=>"machine", :aws_location=>"bucket-name/your-image.manifest.xml", 
      #  :aws_kernel_id=>"aki-a71cf9ce", :aws_state=>"available", :aws_ramdisk_id=>"ari-a51cf9cc", 
      #  :aws_is_public=>false}
      def list
        @aws.describe_images_by_owner('self') || []
      end
      
      # +id+ AMI ID to deregister (ami-XXXXXXX)
      # Returns true when successful. Otherwise throws an exception.
      def deregister(id)
        @aws.deregister_image(id)
      end
      
      # +path+ the S3 path to the manifest (bucket/file.manifest.xml)
      # Returns the AMI ID when successful, otherwise throws an exception.
      def register(path)
        @aws.register_image(path)
      end
    end
    class Snapshots
      include Rudy::AWS::ObjectBase
      
      def list
        @aws.describe_snapshots || []
      end
      
      def create(vol_id)
        @aws.create_snapshot(vol_id)
      end
      
      def destroy(snap_id)
        @aws.delete_snapshot(snap_id)
      end
      
      def exists?(id)
        list.each do |v|
          return true if v[:aws_id] === id
        end
        false
      end
      
    end
    
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
        (list_as_hash || {}).values
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
      (list_as_hash && !list_as_hash.empty?)
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