
module Rudy; module AWS
  module EC2
    module Base
      attr_accessor :ec2
      def initialize(access_key=nil, secret_key=nil, logger=nil)
        @ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
        @logger = logger
      end
    end
    
    class MalformedResponse < RuntimeError; end
    class NoRunningInstances < RuntimeError; end
    class UnknownState < RuntimeError; end
    class NoGroup < RuntimeError; end
    class NoKeyPair < RuntimeError; end
    class NoAMI < RuntimeError; end
    
    # TODO: Look for a generic insecure permissions exception (via OpenSSL?)
    class InsecureKeyPairPermissions < RuntimeError; end
    class ErrorCreatingAddress < RuntimeError; end
    class UnknownAddress < RuntimeError; end
    class NoInstanceID < RuntimeError; end
    class NoAddress < RuntimeError; end
    class AddressNotAssociated < RuntimeError; end
    class AddressAssociated < RuntimeError; end
    
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
    
    class NoVolumeID < RuntimeError; end
    class VolumeAlreadyAttached < RuntimeError; end
    class VolumeNotAttached < RuntimeError; end
    class VolumeNotAvailable < RuntimeError; end
    class NoInstanceID < RuntimeError; end
    class NoDevice < RuntimeError; end
    class UnknownState < RuntimeError; end
    
    
  end
end; end