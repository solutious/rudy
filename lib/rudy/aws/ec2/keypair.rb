
module Rudy::AWS
  module EC2
    
    class Keypair < Storable
      
      field :name => String
      field :fingerprint => String
      field :private_key   => String
      
      def to_s(titles=false)
        [@name.bright, @fingerprint].join '; '
      end
      
      def public_key
        return unless @private_key
        k = Rye::Key.new(@private_key)
        k.public_key.to_ssh2
      end

    end
    
    module EC2::Keypairs
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend
      
      def create(name)
        raise "No name provided" unless name
        ret = @@ec2.create_keypair(:key_name => name)
        from_hash(ret)
      end
      
      def destroy(name)
        name = name.name if name.is_a?(Rudy::AWS::EC2::Keypair)
        raise "No name provided" unless name.is_a?(String)
        ret = @@ec2.delete_keypair(:key_name => name)
        (ret && ret['return'] == 'true') # BUG? Always returns true
      end
      
      def list(*names)
        keypairs = list_as_hash(names)
        keypairs &&= keypairs.values
        keypairs
      end
      
      def list_as_hash(*names)
        names = names.flatten
        klist = @@ec2.describe_keypairs(:key_name => names)
        return unless klist['keySet'].is_a?(Hash)
        keypairs = {}
        klist['keySet']['item'].each do |oldkp| 
          kp = from_hash(oldkp)
          keypairs[kp.name] = kp
        end
        keypairs = nil if keypairs.empty?
        keypairs
      end
      
      def from_hash(h)
        # keyName: test-c5g4v3pe
        # keyFingerprint: 65:d0:ce:e7:6a:b0:88:4a:9c:c7:2d:b8:33:0c:fd:3b:c8:0f:0a:3c
        # keyMaterial: |-
        #   -----BEGIN RSA PRIVATE KEY-----
        # 
        keypair = Rudy::AWS::EC2::Keypair.new
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
        return false unless name
        kp = get(name) rescue nil
        !kp.nil?
      end
      
    end
        
  end
end


