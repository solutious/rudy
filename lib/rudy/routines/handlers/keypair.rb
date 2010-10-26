
module Rudy; module Routines; module Handlers;
  module Keypair
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions(name=nil)
      name ||= current_machine_root
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
    
    def create(name=nil)
      name ||= current_machine_root
      keyname = user_keypairname name
      kp_file = pkey name

      if registered? name && !@@global.force 
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      end

      if Rudy::AWS::EC2::Keypairs.exists? keyname
        if @@global.force
          li "Destroying existing keypair: #{keyname}"
          Rudy::AWS::EC2::Keypairs.destroy keyname
        else
          raise Rudy::AWS::EC2::KeypairAlreadyDefined, keyname
        end
      end
      
      if File.exists?(kp_file)
        if @@global.force
          delete_pkey name
        else
          raise PrivateKeyFileExists, kp_file 
        end
      end
      
      li "Creating keypair: #{keyname}"
      kp = Rudy::AWS::EC2::Keypairs.create(keyname)
      li "Saving #{kp_file}"
      Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      
      kp
    end
    
    def unregister(name=nil)
      name ||= current_machine_root
      keyname = user_keypairname name
      raise "Keypair not registered: #{keyname}" unless registered?(name)
      Rudy::AWS::EC2::Keypairs.destroy keyname
    end
    
    def delete_pkey(name=nil)
      name ||= current_machine_root
      kp_file = pkey name
      raise PrivateKeyNotFound, kp_file unless pkey?(name)
      File.unlink kp_file
    end
    
    def exists?(name=nil)
      name ||= current_machine_root
      registered?(name) && pkey?(name)
    end
    
    def registered?(name=nil)
      name ||= current_machine_root
      keyname = user_keypairname name
      Rudy::AWS::EC2::Keypairs.exists?(keyname)
    end
    
    def pkey(name=nil)
      name ||= current_machine_root
      user_keypairpath name
    end
    
    def pkey?(name=nil)
      name ||= current_machine_root
      File.exists? pkey(name)
    end
    
  end
end; end; end