

module Rudy
  module CLI
    class Addresses < Rudy::CLI::Base


      def associate_addresses_valid?
        raise "You have not supplied an IP addresses" unless @argv.address
        raise "You did not supply an instance ID" unless @argv.instanceid
        
        @inst = @ec2.instances.get(@argv.instanceid)
        raise "Instance #{@inst[:aws_instance_id]} does not exist!" unless @inst
        
        raise "That's not an elastic IP you own!" unless @ec2.addresses.valid?(@argv.address)
        raise "#{@argv.address} is already associated!" if @ec2.addresses.associated?(@argv.address)
        
        true
      end
      
      def associate_addresses
        puts "Associating #{@argv.address} to #{@inst[:aws_groups]}: #{@inst[:dns_name]}"
        
        puts "Done!"
        puts
        
        addresses
      end
      
      def addresses
        puts "Elastic IP mappings:"
        @ec2.addresses.list.each do |address|
          print "IP: #{address[:public_ip]} "
          if address[:instance_id]
            inst = @ec2.instances.get(address[:instance_id])
            puts "%s: %s %s" % [inst[:aws_groups], inst[:aws_instance_id], inst[:dns_name]]
          end
        end
        puts
      end
      
    end
  end
end

