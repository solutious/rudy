
module Rudy; module Routines; module Handlers;
  module Keypair
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions(name=:root)
      keyname = user_keypairname name
      kp_file = pkey name
      if registered? keyname
        # This means no keypair file can be found
        raise PrivateKeyNotFound, keyname if kp_file.nil?
        # This means we found a keypair in the config but we cannot find the private key file. 
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      else
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
      end 
    end
    
    def create(name=:root)
      keyname = user_keypairname name
      kp_file = pkey name
      kp = nil
      if registered? keyname 
        raise PrivateKeyNotFound, keyname if kp_file.nil?
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      else
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
        li "Creating keypair: #{keyname}"
        kp = Rudy::AWS::EC2::Keypairs.create(keyname)
        li "Saving #{kp_file}"
        Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      end
      kp
    end
    
    def unregister(name=:root)
      keyname = user_keypairname name
      raise "Keypair not registered: #{keyname}" unless registered?(name)
      Rudy::AWS::EC2::Keypairs.destroy keyname
    end
    
    def delete_pkey(name=:root)
      kp_file = pkey name
      raise PrivateKeyNotFound, kp_file unless pkey?(name)
      File.unlink kp_file
    end
    
    def exists?(name=:root)
      registered?(name) && pkey?(name)
    end
    
    def registered?(name=:root)
      keyname = user_keypairname name
      Rudy::AWS::EC2::Keypairs.exists? keyname
    end
    
    def pkey(name=:root)
      user_keypairpath name
    end
    
    def pkey?(name=:root)
      File.exists? pkey(name)
    end
    
  end
end; end; end