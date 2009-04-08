

module Rudy
  module CLI
    class Addresses < Rudy::CLI::Base


      def associate_addresses_valid?
        raise "You have not supplied an IP addresses" unless @argv.ipaddress
        raise "You did not supply an instance ID" unless @argv.instanceid
        
        @rmach = Rudy::Machines.new(:config => @config, :global => @global)
        @radd = Rudy::Addresses.new(:config => @config, :global => @global)
        
        raise "Instance #{@argv.instid} does not exist!" unless @rmach.exists?(@argv.instid)
        
        raise "#{@argv.ipaddress} is not allocated to you" unless @radd.exists?(@argv.ipaddress)
        raise "#{@argv.ipaddress} is already associated!" if @radd.associated?(@argv.ipaddress)
        
        true
      end
      
      def associate_addresses
        puts "Associating #{@argv.address} to #{@inst[:aws_groups]}: #{@inst[:dns_name]}"
        
        address = @radd.get(@argv.ipaddress)
        puts address.to_s
        
        puts "Done!"
        puts
      end
      
      def addresses
        puts "Addresses".bright, $/
        
        radd = Rudy::Addresses.new(:config => @config, :global => @global)
        addresses = radd.list || []
        
        addresses.each do |address|
          puts address.to_s
        end
        
        puts "No Addresses" if addresses.empty?
      end
      
      
      def addresses_create
        puts "Create Address".bright, $/
        radd = Rudy::Addresses.new(:config => @config, :global => @global)
        address = radd.create
        puts address.to_s
      end
      
      def addresses_destroy_valid?
        raise "You have not supplied an IP addresses" unless @argv.ipaddress
        
        @radd = Rudy::Addresses.new(:config => @config, :global => @global)
        @rmach = Rudy::Machines.new(:config => @config, :global => @global)
        
        raise "#{@argv.ipaddress} is not allocated to you" unless @radd.exists?(@argv.ipaddress)
        raise "#{@argv.ipaddress} is associated!" if @radd.associated?(@argv.ipaddress)
        
        true
      end
      def addresses_destroy
        puts "Destroy Address".bright, $/
        
        address = @radd.get(@argv.ipaddress)
        raise "Could not fetch #{address.ipaddress}" unless address
        
        puts "Destroying address: #{@argv.ipaddress}"
        puts "NOTE: this IP address will become available to other EC2 customers.".color(:blue)
        exit unless Annoy.are_you_sure?(:low)
        
        ret = @radd.destroy(@argv.ipaddress)
        raise "Destroy failed" unless ret
        
        puts
        puts "Done"
      end
        
    end
  end
end

