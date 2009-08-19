
group "EC2"
library :rudy, 'lib'


tryouts "Keypairs" do
  set :global, Rudy::Huxtable.global
  set :keypair_name, 'key-' << Rudy::Utils.strand
  
  setup do
    Rudy::Huxtable.update_config
    #Rudy::Huxtable.global.region = :'eu-west-1'
    Rudy::AWS::EC2.connect global.accesskey, global.secretkey, global.region
  end
  
  drill "no existing keypairs", false do
    Rudy::AWS::EC2::Keypairs.any?
  end
  
  dream [Rudy::AWS::EC2::Keypair, false]
  drill "create keypair" do
    k = Rudy::AWS::EC2::Keypairs.create keypair_name
    [k.class, k.private_key.nil?]
  end
  
  drill "get keypair", :class, Rudy::AWS::EC2::Keypair do
    Rudy::AWS::EC2::Keypairs.get keypair_name
  end
  
  drill "has fingerprint", :empty?, false do
    k = Rudy::AWS::EC2::Keypairs.get keypair_name
    k.fingerprint
  end
  
  drill "private key is not available later", nil do
    k = Rudy::AWS::EC2::Keypairs.get keypair_name
    k.private_key
  end
  
  dream :class, Array
  dream :empty?, false
  drill "list keypairs" do
    Rudy::AWS::EC2::Keypairs.list
  end
  
  drill "destroy keypairs", nil do
    keypairs = Rudy::AWS::EC2::Keypairs.list
    keypairs.each do |kp|
      Rudy::AWS::EC2::Keypairs.destroy kp.name
    end
    Rudy::AWS::EC2::Keypairs.list
  end
  
end

