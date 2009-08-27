

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Addresses < Rudy::CLI::CommandBase
    
    def addresses_create
      address = Rudy::AWS::EC2::Addresses.create
      print_stobject address
    end
    
    def addresses_destroy_valid?
      raise Drydock::ArgError.new("IP address", @alias) unless @argv.ipaddress
      raise "#{@argv.ipaddress} is not allocated to you" unless Rudy::AWS::EC2::Addresses.exists?(@argv.ipaddress)
      raise "#{@argv.ipaddress} is associated!" if Rudy::AWS::EC2::Addresses.associated?(@argv.ipaddress)
      true
    end
    def addresses_destroy
      address = Rudy::AWS::EC2::Addresses.get(@argv.ipaddress)
      raise "Could not fetch #{address.ipaddress}" unless address
      
      li "Destroying address: #{@argv.ipaddress}"
      li "NOTE: this IP address will become available to other EC2 customers.".bright
      execute_check(:medium)
      execute_action { Rudy::AWS::EC2::Addresses.destroy(@argv.ipaddress) }
    end

    def associate_addresses_valid?
      raise Drydock::ArgError.new('IP address', @alias) if !@argv.ipaddress && !@option.newaddress
      raise Drydock::OptError.new('instance ID', @alias) if !@option.instance
      true
    end
    def associate_addresses
      raise "Instance #{@argv.instid} does not exist!" unless Rudy::AWS::EC2::Instances.exists?(@option.instance)
      
      if @option.newaddress
        print "Creating address... "
        tmp = Rudy::AWS::EC2::Addresses.create
        li "#{tmp.ipaddress}"
        address = tmp.ipaddress
      else
        address = @argv.ipaddress
      end
      
      raise "#{address} is not allocated to you" unless Rudy::AWS::EC2::Addresses.exists?(address)
      raise "#{address} is already associated!" if Rudy::AWS::EC2::Addresses.associated?(address)
          
      instance = Rudy::AWS::EC2::Instances.get(@option.instance)
      
      # If an instance was recently disassoiciated, the dns_public may
      # not be updated yet
      instance_name = instance.dns_public
      instance_name = instance.awsid if !instance_name || instance_name.empty?
      
      li "Associating #{address} to #{instance_name} (#{instance.groups.join(', ')})"
      execute_check(:low)
      execute_action { Rudy::AWS::EC2::Addresses.associate(address, instance.awsid) }
      address = Rudy::AWS::EC2::Addresses.get(address)
      print_stobject address
    end
    
    def disassociate_addresses_valid?
      raise "You have not supplied an IP addresses" unless @argv.ipaddress
      true
    end
    def disassociate_addresses
      raise "#{@argv.ipaddress} is not allocated to you" unless Rudy::AWS::EC2::Addresses.exists?(@argv.ipaddress)
      raise "#{@argv.ipaddress} is not associated!" unless Rudy::AWS::EC2::Addresses.associated?(@argv.ipaddress)
      
      address = Rudy::AWS::EC2::Addresses.get(@argv.ipaddress)
      instance = Rudy::AWS::EC2::Instances.get(address.instid)
      
      li "Disassociating #{address.ipaddress} from #{instance.awsid} (#{instance.groups.join(', ')})"
      execute_check(:medium)
      execute_action { Rudy::AWS::EC2::Addresses.disassociate(@argv.ipaddress) }
      address = Rudy::AWS::EC2::Addresses.get(@argv.ipaddress)
      print_stobject address
    end
    
    def addresses
      addresses = Rudy::AWS::EC2::Addresses.list || []
      print_stobjects addresses
    end
    
    
  end

end; end
end; end

