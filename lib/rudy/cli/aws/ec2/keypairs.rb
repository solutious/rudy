

module Rudy; module CLI; 
module AWS; module EC2;
  
  class EC2::Keypairs < Rudy::CLI::CommandBase
    
    def create_keypairs_valid?
      raise Drydock::ArgError.new('name', @alias) unless @argv.name
      true
    end
    def create_keypairs
      kp = execute_action { Rudy::AWS::EC2::Keypairs.create(@argv.name) }
      if [:s, :string].member?(@@global.format)
        puts "Name: #{kp.name}"
        puts "Fingerprint: #{kp.fingerprint}", $/
        puts "Copy the following private key data into a file."
        puts "Set the permissions to 0600 and keep it safe.", $/
        puts kp.private_key
      else
         print_stobject kp
      end
    end
    
    def destroy_keypairs_valid?
      raise Drydock::ArgError.new('name', @alias) unless @argv.name
      true
    end
    def destroy_keypairs
      raise "Keypair #{@argv.name} does not exist" unless Rudy::AWS::EC2::Keypairs.exists?(@argv.name)
      kp = Rudy::AWS::EC2::Keypairs.get(@argv.name)
      puts "Destroying: #{kp.name}"
      execute_check(:medium)
      execute_action { Rudy::AWS::EC2::Keypairs.destroy(kp.name) }
    end
    
    def keypairs
      klist = Rudy::AWS::EC2::Keypairs.list
      print_stobjects klist
    end
    
    
  end


end; end
end; end
