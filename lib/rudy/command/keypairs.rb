
module Rudy
  class KeyPairs
    include Rudy::Huxtable

    #def check_permissions(n=nil)
    #  n ||= name(n)
    #  raise NoPrivateKeyFile, self.path(n) unless File.exists?(self.path(n))
    #  raise InsecureKeyPairPermissions, self.path(n) unless File::Stat....
    #  p n
    #end
    
      
    def destroy(n=nil)
      n ||= name(n)
      raise "KeyPair #{n} doesn't exist" unless exists?(n)
      @@logger.puts "No private key file: #{self.path(n)}. Continuing..." unless File.exists?(self.path(n))
      @@logger.puts "Unregistering KeyPair with Amazon"
      ret = @@ec2.keypairs.destroy(n)
      if ret
        ret = delete_files(n) if ret # only delete local file if remote keypair is successfully destroyed
      else
        @@logger.puts "Keypair not destroyed successfully."
      end
      ret
    end
    
    # Lists the keypairs registered with Amazon
    def list(n=nil, &each_object)
      n &&= [n].flatten.compact
      keypairs = @@ec2.keypairs.list(n)
      keypairs.each { |n,kp| each_object.call(kp) } if each_object
      keypairs || []
    end
    
    def get(n=nil)
      n ||= name(n)
      keypairs = @@ec2.keypairs.list(n) || []
      keypairs.first
    end
    
    def list_as_hash(n=nil, &each_object)
      n &&= [n].flatten.compact
      keypairs = @@ec2.keypairs.list_as_hash(n)
      keypairs.each_pair { |n,kp| each_object.call(kp) } if each_object
      keypairs || {}
    end
    
    def exists?(n=nil)
      n ||= name(n)
      @@ec2.keypairs.exists?(n)
    end
    
    def any?(n=nil)
      n ||= name(n)
      @@ec2.keypairs.any?    
    end
    
    def name(n=nil)
      n ||= "key-#{current_machine_group}"
      n
    end
      
    def path(n=nil)
      n ||= name(n)
      File.join(self.config_dirname, "#{n}")
    end
    
    def public_path(n=nil)
      n ||= name(n)
      File.join(self.config_dirname, "#{n}.pub")
    end
    

    # We use the base file name to determine the registered keypair name.
    def KeyPairs.path_to_name(path)
      return unless path
      return path unless File.exists?(path)
      File.basename(path)
    end
    
  private
    def delete_files(n=nil)
      n ||= name(n)
      
      if File.exists? self.path(n)  
        @@logger.puts "Deleting #{self.path(n)}"
        ret = (File.unlink(self.path(n)) > 0) rescue false;
      else
        ret = true
      end
      if File.exists?(self.public_path(n))
        @@logger.puts "Deleting #{self.public_path(n)}" 
        ret = ret && (File.unlink(self.public_path(n)) > 0)
      end
      ret
    end

  end

end

module Rudy
  class KeyPairs

  end
end