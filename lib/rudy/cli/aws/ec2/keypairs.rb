

module Rudy; module CLI; 
module AWS; module EC2;
  
  class KeyPairs < Rudy::CLI::Base
    
    def create_keypairs_valid?
      raise ArgumentError, "No name provided" unless @argv.name
      true
    end
    def create_keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      kp = execute_action { rkey.create(@argv.name) }
      puts "Name: #{kp.name}"
      puts "Fingerprint: #{kp.fingerprint}", $/
      puts "Copy the following private key data into a file."
      puts "Set the permissions to 0600 and keep it safe.", $/
      puts kp.private_key
    end
    
    def destroy_keypairs_valid?
      raise ArgumentError, "No name provided" unless @argv.name
      true
    end
    def destroy_keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      raise "KeyPair #{@argv.name} does not exist" unless rkey.exists?(@argv.name)
      kp = rkey.get(@argv.name)
      puts "Destroying: #{kp.name}"
      execute_check(:medium)
      execute_action { rkey.destroy(kp.name) }
      keypairs
    end
    
    def keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      rkey.list.each do |kp|
        puts kp.to_s
      end
      puts "No keypairs" unless rkey.any?
    end
    
    
  end


end; end
end; end
