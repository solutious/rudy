
module Rudy::Test
  
  class TC_21_EC2
    
    xcontext "(10) #{name} KeyPairs" do
      
      
      should "(01) create keypair" do
        name = 'test-' << Rudy::Utils.strand
        keypair = @@ec2.keypairs.create(name)
        assert keypair.is_a?(Rudy::AWS::EC2::KeyPair), "Not a KeyPair"
        assert !keypair.name.empty?, "No name"
        assert !keypair.fingerprint.empty?, "No fingerprint"
        assert !keypair.private_key.empty?, "No private key"
      end
      
      should "(10) list keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
      end
      
      should "(50) destroy keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
        keypairs.each do |kp|
          @@ec2.keypairs.destroy(kp.name)
        end
      end
    end
    
  end
end
