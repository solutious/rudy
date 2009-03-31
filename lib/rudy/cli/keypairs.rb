

module Rudy
  module CLI
    class KeyPairs < Rudy::CLI::Base

      def create_keypairs
        puts "Create KeyPairs".bright
        rkey = Rudy::Keypairs.new(:config => @config, :global => @global)
        name = @argv.kpname
        rkey.create

      end
      
      
      def destroy_keypairs
        puts "Destroy KeyPairs #{@argv.kpname}".bright
        rkey = Rudy::KeyPairs.new(:config => @config, :global => @global)
        raise "KeyPair #{rkey.name(@argv.kpname)} does not exist" unless rkey.exists?(@argv.kpname)
        kp = rkey.get(@argv.kpname)
        puts "Destroying keypair: #{kp.name}"
        puts "NOTE: the private key file will also be deleted and you will not be able to"
        puts "connect to instances started with this keypair."
        exit unless Annoy.are_you_sure?(:low)
        #ret = kp.destroy
        #puts ret ? "Success" : "Failed"
      end
      
      def keypairs
        puts "KeyPairs".bright
        rmach = Rudy::Machines.new(:config => @config, :global => @global)
        ec2 = rmach.ec2
        ec2.keypairs.list.each do |kp|
          puts kp.to_s
        end
      end
      
      
    end
  end
end