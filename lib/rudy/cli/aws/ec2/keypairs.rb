

module Rudy; module CLI; 
module AWS; module EC2;
  
  class KeyPairs < Rudy::CLI::Base
    
    def create_keypairs_valid?
      raise "No name provided" unless @argv.kpname
      true
    end
    
    def create_keypairs
      puts "Create KeyPairs".bright
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      
      kp = rkey.create(@argv.kpname)
      puts "Name: #{kp.name}"
      puts "Fingerprint: #{kp.fingerprint}"
      
      puts "Copy the following private key data into a file."
      puts "Set the permissions to 0600 and keep it safe."
      puts kp.private_key
    end
    
    def destroy_keypairs_valid?
      raise "No name provided" unless @argv.kpname
      true
    end
    def destroy_keypairs
      puts "Destroy KeyPairs".bright
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      raise "KeyPair #{@argv.kpname} does not exist" unless rkey.exists?(@argv.kpname)
      kp = rkey.get(@argv.kpname)
      puts "Destroying keypair: #{kp.name}"
      #puts "NOTE: the private key file will also be deleted and you will not be able to".color(:blue)
      #puts "connect to instances started with this keypair.".color(:blue)
      exit unless Annoy.are_you_sure?(:medium)
      ret = rkey.destroy(@argv.kpname)
      puts ret ? "Success" : "Failed"
    end
    
    def keypairs
      puts "KeyPairs".bright
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey)
      
      rkey.list.each do |kp|
        puts kp.to_s
      end
      
      puts "No keypairs" unless rkey.any?
      
    end
    
    
  end


end; end
end; end
