
module Rudy; module AWS
  module EC2
    module Base
      attr_accessor :ec2
      def initialize(access_key=nil, secret_key=nil, region=nil, logger=nil)
        
        if region
          raise InvalidRegion, region unless Rudy::AWS.valid_region?(region)
          host = "#{region}.ec2.amazonaws.com"
        elsif ENV['EC2_URL']
          host = URL.parse(ENV['EC2_URL']).host
        end
        
        host ||= DEFAULT_EC2_HOST
        port ||= DEFAULT_EC2_PORT
        
        @ec2 = ::EC2::Base.new(:port => port, :server=> host, :access_key_id => access_key, :secret_access_key => secret_key)
        @logger = logger
      end
    end
    
    class NoRunningInstances < Rudy::Error; end
    class MalformedResponse < Rudy::Error; end
    class InvalidRegion < Rudy::Error; end
    class UnknownState < Rudy::Error; end
    class NoGroup < Rudy::Error; end
    class NoKeyPair < Rudy::Error; end
    class NoAMI < Rudy::Error; end
    
    class NoAddress < Rudy::Error; end
    class UnknownAddress < Rudy::Error; end
    class NoInstanceID < Rudy::Error; end
    class AddressAssociated < Rudy::Error; end
    class ErrorCreatingAddress < Rudy::Error; end
    class AddressNotAssociated < Rudy::Error; end
    class InsecureKeyPairPermissions < Rudy::Error; end
    
    class InsecureKeyPairPermissions < Rudy::Error; end
    class ErrorCreatingKeyPair < Rudy::Error; end
    class NoPrivateKeyFile < Rudy::Error; end
    class KeyPairExists < Rudy::Error; end
    class KeyPairAlreadyDefined < Rudy::Error
      def message
        "A keypair is defined for #{@obj}. Check your Rudy config."
      end
    end
    
    class VolumeAlreadyAttached < Rudy::Error; end
    class VolumeNotAvailable < Rudy::Error; end
    class VolumeNotAttached < Rudy::Error; end
    class NoInstanceID < Rudy::Error; end
    class NoVolumeID < Rudy::Error; end
    class UnknownState < Rudy::Error; end
    class NoDevice < Rudy::Error; end
    
    
  end
end; end