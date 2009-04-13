
module Rudy::Test

  class Case_25_EC2
    
    context "#{name}_30 Addresses" do
      setup do
        @ec2add = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
        #@ami = @@config.machines.find(@@zone.to_sym, :ami)
      end
      
      should "(00) not be existing addresses" do
        stop_test @ec2add.any?, "Destroy the existing addresses"
      end
      
      should "(01) create address" do
        address = @ec2add.create
        assert address.is_a?(Rudy::AWS::EC2::Address), "Did not create"
        assert address.ipaddress.size > 0, "Address length is 0"
      end
      
      should "(10) list available addresses" do
        assert @ec2add.any?, "No addresses"
        assert @ec2add.list_as_hash.is_a?(Hash), "Not a Hash"
        assert @ec2add.list.is_a?(Array), "Not an Array"
        assert_equal 1, @ec2add.list.size, "More than one address"
      end
      
      should "(50) destroy address" do
        assert @ec2add.any?, "No addresses"
        @ec2add.list.each do |address|
          assert @ec2add.destroy(address), "Did not destroy"
        end
      end
      
    end

  end
end