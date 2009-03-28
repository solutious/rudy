

module Rudy
  class Addresses
    include Rudy::Huxtable
    
    def create
      
    end
    
    def destroy
      
    end
    
    def assign(address, instance)
      raise "Not an instance object" unless instance.is_a?(Rudy::AWS::EC2::Instance)
      raise "Address not available for this account" unless @ec2.addresses.valid?(address)
      @ec2.addresses.associate(instance.awsid, address)
    end
    
  end
end