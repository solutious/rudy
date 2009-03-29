

module Rudy::AWS
  class EC2
    
    class KeyPair < Storable
      attr_accessor :private_key # never saved
      field :name
      field :fingerprint
    end
    
    class KeyPairs
      include Rudy::AWS::ObjectBase
      
      def create(name)
        raise "No name provided" unless name
        ret = @aws.create_keypair(:key_name => name)
        self.class.from_hash(ret)
      end
      
      def destroy(name)
        name = name.name if name.is_a?(Rudy::AWS::EC2::KeyPair)
        raise "No name provided" unless name.is_a?(String)
        ret = @aws.delete_keypair(:key_name => name)
        (ret && ret['return'] == 'true')
      end
      
      def list(*names)
        keypairs = list_as_hash
        keypairs &&= keypairs.values
        keypairs
      end
      
      def list_as_hash(*names)
        names = names.flatten
        klist = @aws.describe_keypairs(:key_name => names)
        return unless klist['keySet'].is_a?(Hash)
        keypairs = {}
        klist['keySet']['item'].each do |oldkp| 
          kp = self.class.from_hash(oldkp)
          keypairs[kp.name] = kp
        end
        keypairs
      end
      
      def self.from_hash(h)
        # keyName: test-c5g4v3pe
        # keyFingerprint: 65:d0:ce:e7:6a:b0:88:4a:9c:c7:2d:b8:33:0c:fd:3b:c8:0f:0a:3c
        # keyMaterial: |-
        #   -----BEGIN RSA PRIVATE KEY-----
        # 
        keypair = Rudy::AWS::EC2::KeyPair.new
        keypair.fingerprint = h['keyFingerprint']
        keypair.name = h['keyName']
        keypair.private_key = h['keyMaterial']
        keypair
      end
      
      def any?
        keypairs = list
      end
      
      def exists?(name)
        
      end
    end
  end
end
