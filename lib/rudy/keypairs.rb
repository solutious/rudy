
module Rudy
  class KeyPairs
    include Rudy::Huxtable
    
    
    def create(n=nil, opts={})
      n ||= name(n)
      
      opts = {
        :force => false
      }.merge(opts)
      
      delete_pk(n) if opts[:force] == true && File.exists?(self.path(n))
      raise "Private key already exists: #{self.path(n)}" if File.exists?(self.path(n))
      
      kp = @@ec2.keypairs.create(n)
      raise "Error creating #{n} keypair" unless kp.is_a?(Rudy::AWS::EC2::KeyPair)
      
      @logger.puts "Writing #{self.path(n)}"
      Rudy::Utils.write_to_file(self.path(n), kp.private_key, 'w')
      
      @logger.puts "Writing #{self.public_path(n)}"
      Rudy::Utils.write_to_file(self.public_path(n), kp.public_key, 'w')
      
      @logger.puts "NOTE: If you move #{self.path(n)} you need to also update your Rudy machines config."
      
      kp
    end
    
    def destroy(n=nil)
      n ||= name(n)
      raise "KeyPair #{n} doesn't exist" unless exists?(n)
      @logger.puts "No private key file: #{self.path(n)}. Continuing..." unless File.exists?(self.path(n))
      @logger.puts "Unregistering KeyPair with Amazon"
      ret = @@ec2.keypairs.destroy(n)
      delete_files(n)
    end
    
    def list(n=nil, &each_object)
      n ||= name(n)
      n &&= [n]
      keypairs = @@ec2.keypairs.list(n)
      keypairs.each { |n,kp| each_object.call(kp) } if each_object
      keypairs
    end
    
    def list_as_hash(n=nill, &each_object)
      n ||= name(n)
      n &&= [n]
      keypairs = @@ec2.keypairs.list_as_hash(n)
      keypairs.each_pair { |n,kp| each_object.call(kp) } if each_object
      keypairs
    end
    
    def exists?(n=nil)
      n ||= name(n)
      @@ec2.keypairs.exists?(n)
    end
    
    def any?(n=nil)
      n ||= name(n)
      @@ec2.keypairs.any?    end
    
    def name(n=nil)
      n ||= current_machine_group
      "key-#{n}"
    end
      
    def path(n=nil)
      n ||= name(n)
      File.join(self.dirname, "#{n}.private")
    end
    
    def public_path(n=nil)
      n ||= name(n)
      File.join(self.dirname, "#{n}.pub")
    end
  
    def dirname
      raise "No config paths defined" unless @config.is_a?(Rudy::Config) && @config.paths.is_a?(Array)
      base_dir = File.dirname @config.paths.first
      raise "Config directory doesn't exist #{base_dir}" unless File.exists?(base_dir)
      base_dir
    end
    
  private
    def delete_files(n=nil)
      n ||= name(n)
      return false unless File.exists?(self.path(n))
      @logger.puts "Deleting #{self.path(n)}"
      (File.unlink(self.path(n)) > 0)      # raise exception on error. handle?
      
      return false unless File.exists?(self.public_path(n))
      @logger.puts "Deleting #{self.public_path(n)}"
      (File.unlink(self.public_path(n)) > 0)
    end

  end
end