
module Rudy::Test
  
  class Case_25_EC2
    
    context "#{name}_10 KeyPairs" do
      setup do
        @@test_name ||= 'test-' << Rudy::Utils.strand
        @ec2key = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey, @@global.region)
        #@ami = @@config.machines.find(@@zone.to_sym, :ami)
      end
      
      
      should "(10) create keypair" do
        keypair = @ec2key.create(@@test_name)
        assert keypair.is_a?(Rudy::AWS::EC2::KeyPair), "Not a KeyPair"
        assert !keypair.name.empty?, "No name"
        assert !keypair.fingerprint.empty?, "No fingerprint"
        assert !keypair.private_key.empty?, "No private key"
      end
      
      should "(20) list keypairs" do
        keypairs = @ec2key.list || []
        assert keypairs.size > 0, "No keypairs"
      end
      
      should "(21) get specific keypair" do
        assert @ec2key.get(@@test_name).is_a?(Rudy::AWS::EC2::KeyPair), "Not a KeyPair (#{@@test_name})"
      end
      
      should "(50) destroy keypairs" do
        keypairs = @ec2key.list || []
        assert keypairs.size > 0, "No keypairs"
        keypairs.each do |kp|
          @ec2key.destroy(kp.name)
        end
      end
    end
    
  end
end
