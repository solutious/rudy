

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Addresses < Rudy::CLI::Base
    
    def addresses_create
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      address = radd.create
      puts address.dump(@@global.format)
    end
    
    def addresses_destroy_valid?
      raise ArgumentError, "You have not supplied an IP addresses" unless @argv.ipaddress
      @radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      raise "#{@argv.ipaddress} is not allocated to you" unless @radd.exists?(@argv.ipaddress)
      raise "#{@argv.ipaddress} is associated!" if @radd.associated?(@argv.ipaddress)
      true
    end
    def addresses_destroy
      address = @radd.get(@argv.ipaddress)
      raise "Could not fetch #{address.ipaddress}" unless address
      
      puts "Destroying address: #{@argv.ipaddress}"
      puts "NOTE: this IP address will become available to other EC2 customers.".color(:blue)
      execute_check(:medium)
      execute_action { @radd.destroy(@argv.ipaddress) }
      self.addresses
    end

    def associate_addresses_valid?
      raise ArgumentError, "You have not supplied an IP addresses" if !@argv.ipaddress && !@option.newaddress
      raise OptionError, "You did not supply an instance ID" unless @option.instance
      true
    end
    def associate_addresses
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      
      raise "Instance #{@argv.instid} does not exist!" unless rinst.exists?(@option.instance)
      
      if @option.newaddress
        print "Creating address... "
        tmp = radd.create
        puts "#{tmp.ipaddress}"
        address = tmp.ipaddress
      else
        address = @argv.ipaddress
      end
      
      raise "#{address} is not allocated to you" unless radd.exists?(address)
      raise "#{address} is already associated!" if radd.associated?(address)
          
      instance = rinst.get(@option.instance)
      
      # If an instance was recently disassoiciated, the dns_public may
      # not be updated yet
      instance_name = instance.dns_public
      instance_name = instance.awsid if !instance_name || instance_name.empty?
      
      puts "Associating #{address} to #{instance_name} (#{instance.groups.join(', ')})"
      execute_check(:low)
      execute_action { radd.associate(address, instance.awsid) }
      address = radd.get(address)
      puts address.dump(@@global.format)
    end
    
    def disassociate_addresses_valid?
      raise "You have not supplied an IP addresses" unless @argv.ipaddress
      true
    end
    def disassociate_addresses
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      raise "#{@argv.ipaddress} is not allocated to you" unless radd.exists?(@argv.ipaddress)
      raise "#{@argv.ipaddress} is not associated!" unless radd.associated?(@argv.ipaddress)
      
      address = radd.get(@argv.ipaddress)
      instance = rinst.get(address.instid)
      
      puts "Disassociating #{address.ipaddress} from #{instance.awsid} (#{instance.groups.join(', ')})"
      execute_check(:medium)
      execute_action { radd.disassociate(@argv.ipaddress) }
      address = radd.get(@argv.ipaddress)
      puts address.dump(@@global.format)
    end
    
    def addresses
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      addresses = radd.list || []
      
      addresses.each do |address|
        puts address.dump(@@global.format)
      end
      
      puts "No Addresses" if addresses.empty?
    end
    
    
  end

end; end
end; end

