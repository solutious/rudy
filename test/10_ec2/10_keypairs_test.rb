
module Rudy::Test
  
  class EC2
    
    context "(10) EC2 KeyPairs" do
      should "(01) create keypair" do
        name = 'test-' << Rudy::Utils.strand
        keypair = @@ec2.keypairs.create(name)
        assert keypair.is_a?(Rudy::AWS::EC2::KeyPair), "Not a KeyPair"
        assert !keypair.name.empty?, "No name"
        assert !keypair.fingerprint.empty?, "No fingerprint"
        assert !keypair.private_key.empty?, "No private key"
      end
      
      should "(02) list keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
      end
      
      should "(03) destroy keypairs" do
        keypairs = @@ec2.keypairs.list || []
        assert keypairs.size > 0, "No keypairs"
        keypairs.each do |kp|
          @@ec2.keypairs.destroy(kp.name)
        end
      end
    end
    
  end
end
