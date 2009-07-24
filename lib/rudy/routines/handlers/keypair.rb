
module Rudy; module Routines; module Handlers;
  module Keypair
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions(name=nil)
      name ||= root_keypairname
      if registered? name
      else
      end 
    end
    
    def create(name=nil)
      name ||= root_keypairname
      if registered? name 
        kp_file = user_keypairpath name
        # This means no keypair file can be found
        raise PrivateKeyNotFound, name if kp_file.nil?
        # This means we found a keypair in the config but we cannot find the private key file. 
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      else
        kp_file = user_keypairpath name
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
        li "Creating keypair: #{name}"
        #kp = Rudy::AWS::EC2::Keypairs.create(name)
        #li "Saving #{kp_file}"
        #Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      end
    end
    
    def exists?(name=nil)
      name ||= root_keypairname
      registered?(name) && pkey?(name)
    end
    
    def registered?(name=nil)
      name ||= root_keypairname
      Rudy::AWS::EC2::Keypairs.exists? name
    end
    
    def pkey?(name=nil)
      name ||= root_keypairname
      has_user_pkey? name
    end
    
  end
end; end; end