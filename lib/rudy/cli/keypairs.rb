

module Rudy
  module CLI
    class KeyPairs < Rudy::CLI::Base

      def create_keypairs
        puts "Create KeyPairs".bright
        rmach = Rudy::Machines.new(:config => @config, :global => @global)
        name = @argv.kpname || rmach.current_machine_group
        ec2 = rmach.ec2
        kp = ec2.keypairs.create(name)
        puts kp.to_s, $/
        kpfile = File.join('.', "key-#{kp.name}")
        kpfile += '-1' if File.exists?(kpfile)
        kpfile.succ! while File.exists?(kpfile)
        puts "Writing #{kpfile}"
        Rudy::Utils.write_to_file(kpfile, kp.private_key, 'w')
        puts "NOTE: Move #{kpfile} to a safe location and update your Rudy config."
        puts "You will need this key to login as root. "
      end
      
      
      def destroy_keypairs
        puts "Destroy KeyPairs".bright
        rmach = Rudy::Machines.new(:config => @config, :global => @global)
        name = @argv.kpname || rmach.current_machine_group
        ec2 = rmach.ec2
        raise "KeyPair #{name} does not exist" unless ec2.keypairs.exists?(name)
        puts "Destroying keypair: #{name}"
        puts "NOTE: this will invalidate the private key file associated with"
        puts "this keypair. "
        exit unless Annoy.are_you_sure?(:low)
        ret = ec2.keypairs.destroy(name)
        puts ret ? "Success" : "Failed"
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