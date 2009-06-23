
module Rudy; module Routines; module Handlers;
  module Machines
    include Rudy::Routines::Handlers::Base
    extend self
    
    ##Rudy::Routines.add_handler :machines, self
    
    
    def raise_early_exceptions
    end
    
    
    def create_security_group
      unless @rgrp.exists?(current_group_name)
        li "Creating group: #{current_group_name}"
        @rgrp.create(current_group_name)
      end
    end
    
    def create_keypair
      unless @rkey.exists?(root_keypairname)
        kp_file = root_keypairpath
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
        li "Creating keypair: #{root_keypairname}"
        kp = @rkey.create(root_keypairname)
        li "Saving #{kp_file}"
        Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      else
        kp_file = root_keypairpath
        # This means no keypair file can be found
        raise PrivateKeyNotFound, root_keypairname if kp_file.nil?
        # This means we found a keypair in the config but we cannot find the private key file. 
        raise PrivateKeyNotFound, kp_file if !File.exists?(kp_file)
      end
    end
      
    
  end
end; end; end