
module Rudy::Test

  class Case_21_EC2
    
    xcontext "#{name} Addresses" do
      should "(00) not be existing addresses" do
        #p @@ec2.addresses.list
        stop_test @@ec2.addresses.any?, "Destroy the existing addresses"
      end
      
      should "(01) create address" do
        address = @@ec2.addresses.create
        assert address.is_a?(Rudy::AWS::EC2::Address), "Did not create"
        assert address.ipaddress.size > 0, "Address length is 0"
      end
      
      should "(10) list available addresses" do
        assert @@ec2.addresses.any?, "No addresses"
        assert @@ec2.addresses.list_as_hash.is_a?(Hash), "Not a Hash"
        assert @@ec2.addresses.list.is_a?(Array), "Not an Array"
        assert_equal 1, @@ec2.addresses.list.size, "More than one address"
      end
      
      should "(50) destroy address" do
        assert @@ec2.addresses.any?, "No addresses"
        @@ec2.addresses.list.each do |address|
          assert @@ec2.addresses.destroy(address), "Did not destroy"
        end
      end
      
    end

  end
end