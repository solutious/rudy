

module Rudy
  class Addresses
    include Rudy::Huxtable
    include Rudy::AWS
    
    def create
      address = @@ec2.addresses.create
      raise ErrorCreatingAddress unless address.is_a?(Rudy::AWS::EC2::Address)
      address
    end
    
    def destroy(address)
      address = address
      @@ec2.addresses.destroy(address)
    end
    
    def assign(address, instance)
      raise "Not an instance object" unless instance.is_a?(Rudy::AWS::EC2::Instance)
      raise "Address not available for this account" unless @@ec2.addresses.valid?(address)
      @@ec2.addresses.associate(instance.awsid, address)
    end
    
    
    # Lists the addresses registered with Amazon
    def list(n=nil, &each_object)
      n = [n].flatten.compact
      addresses = @@ec2.addresses.list(n)
      addresses.each { |n,kp| each_object.call(kp) } if each_object
      addresses || []
    end
    
    def get(n=nil)
      raise "Address cannot be nil" if n.nil?
      @@ec2.addresses.get(n)
    end
    
    def associated?(n=nil)
      raise "Address cannot be nil" if n.nil?
      @@ec2.addresses.associated?(n)
    end
    
    def list_as_hash(n=nil, &each_object)
      n &&= [n].flatten.compact
      addresses = @@ec2.addresses.list_as_hash(n)
      addresses.each_pair { |n,kp| each_object.call(kp) } if each_object
      addresses || {}
    end
    
    def exists?(n=nil)
      n ||= name(n)
      @@ec2.addresses.exists?(n)
    end
    
    def any?(n=nil)
      n ||= name(n)
      @@ec2.addresses.any?    
    end
    
  end
  
end


module Rudy
  class Addresses 
    class ErrorCreatingAddress < RuntimeError; end
  end
end