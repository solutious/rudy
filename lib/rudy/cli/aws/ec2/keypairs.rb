

module Rudy; module CLI; 
module AWS; module EC2;
  
  class KeyPairs < Rudy::CLI::CommandBase
    
    def create_keypairs_valid?
      raise Drydock::ArgError.new('name', @alias) unless @argv.name
      true
    end
    def create_keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey, @@global.region)
      kp = execute_action { rkey.create(@argv.name) }
      if %w[s string].member?(@@global.format)
        puts "Name: #{kp.name}"
        puts "Fingerprint: #{kp.fingerprint}", $/
        puts "Copy the following private key data into a file."
        puts "Set the permissions to 0600 and keep it safe.", $/
        puts kp.private_key
      else
        puts @@global.verbose > 0 ? kp.inspect : kp.dump(@@global.format)
      end
    end
    
    def destroy_keypairs_valid?
      raise Drydock::ArgError.new('name', @alias) unless @argv.name
      true
    end
    def destroy_keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise "KeyPair #{@argv.name} does not exist" unless rkey.exists?(@argv.name)
      kp = rkey.get(@argv.name)
      puts "Destroying: #{kp.name}"
      execute_check(:medium)
      execute_action { rkey.destroy(kp.name) }
      keypairs
    end
    
    def keypairs
      rkey = Rudy::AWS::EC2::KeyPairs.new(@@global.accesskey, @@global.secretkey, @@global.region)
      (rkey.list || []).each do |kp|
        puts @@global.verbose > 0 ? kp.inspect : kp.dump(@@global.format)
      end
      puts "No keypairs" unless rkey.any?
    end
    
    
  end


end; end
end; end
