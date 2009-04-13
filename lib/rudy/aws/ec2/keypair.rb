
module Rudy::AWS
  module EC2
    
    class KeyPair < Storable
      attr_accessor :private_key  # not a storable field
      
      field :name
      field :fingerprint
      
      def to_s(titles=false)
        str = titles ? "%-20s   %s#{$/}" % ['name', 'fingerprint'] : ""
        str << "%-20s   %s" % [self.name, self.fingerprint]
      end
      
      def public_key
        return unless @private_key
        k = Rye::Key.new(@private_key)
        k.public_key.to_ssh2
      end

    end
    
    class KeyPairs
      include Rudy::AWS::ObjectBase
      include Rudy::AWS::EC2::Base
      
      def create(name)
        raise "No name provided" unless name
        ret = @ec2.create_keypair(:key_name => name)
        self.class.from_hash(ret)
      end
      
      def destroy(name)
        name = name.name if name.is_a?(Rudy::AWS::EC2::KeyPair)
        raise "No name provided" unless name.is_a?(String)
        ret = @ec2.delete_keypair(:key_name => name)
        (ret && ret['return'] == 'true') # BUG? Always returns true
      end
      
      def list(*names)
        keypairs = list_as_hash(names)
        keypairs &&= keypairs.values
        keypairs
      end
      
      def list_as_hash(*names)
        names = names.flatten
        klist = @ec2.describe_keypairs(:key_name => names)
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
        keypairs = list || []
        !keypairs.empty?
      end
      
      def get(name)
        keypairs = list(name) || []
        return if keypairs.empty?
        keypairs.first
      end
      
      def exists?(name)
        begin
          kp = get(name)
          kp.is_a?(Rudy::AWS::EC2::KeyPair)
        rescue => ex
          false
        end
      end
      
    end
    
    class Keypairs
      def initialize(*args)
        raise "Oops! The correct class uses a capital 'P': Rudy::AWS::EC2::KeyPairs"
      end
    end
    
  end
end


class Rudy::AWS::EC2::KeyPairs
  
  class InsecureKeyPairPermissions < RuntimeError; end
  class NoPrivateKeyFile < RuntimeError; end
  class ErrorCreatingKeyPair < RuntimeError; end
  class KeyPairExists < RuntimeError; end
  class KeyPairAlreadyDefined < RuntimeError
    attr_reader :group
    def initialize(group)
      @group = group
    end
    def message
      "A keypair is defined for #{group}. Check your Rudy config."
    end
  end
  
end
