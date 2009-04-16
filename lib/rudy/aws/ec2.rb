
module Rudy; module AWS
  module EC2
    module Base
      attr_accessor :ec2
      def initialize(access_key=nil, secret_key=nil, region=nil, logger=nil)
        
        if region && Rudy::AWS.valid_region?(region)
          server = "#{region}.ec2.amazonaws.com"
        elsif ENV['EC2_URL']
#          server = URL.parse(ENV['EC2_URL']).host
        end
        server ||= DEFAULT_EC2_URL
        
        puts "me: #{server}"
        
        @ec2 = ::EC2::Base.new(:port => 443, :server=> server, :access_key_id => access_key, :secret_access_key => secret_key)
        @logger = logger
      end
    end
    
    class NoRunningInstances < RuntimeError; end
    class MalformedResponse < RuntimeError; end
    class UnknownState < RuntimeError; end
    class NoGroup < RuntimeError; end
    class NoKeyPair < RuntimeError; end
    class NoAMI < RuntimeError; end
    
    class NoAddress < RuntimeError; end
    class UnknownAddress < RuntimeError; end
    class NoInstanceID < RuntimeError; end
    class AddressAssociated < RuntimeError; end
    class ErrorCreatingAddress < RuntimeError; end
    class AddressNotAssociated < RuntimeError; end
    class InsecureKeyPairPermissions < RuntimeError; end
    
    class InsecureKeyPairPermissions < RuntimeError; end
    class ErrorCreatingKeyPair < RuntimeError; end
    class NoPrivateKeyFile < RuntimeError; end
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
    
    class VolumeAlreadyAttached < RuntimeError; end
    class VolumeNotAvailable < RuntimeError; end
    class VolumeNotAttached < RuntimeError; end
    class NoInstanceID < RuntimeError; end
    class NoVolumeID < RuntimeError; end
    class UnknownState < RuntimeError; end
    class NoDevice < RuntimeError; end
    
    
  end
end; end