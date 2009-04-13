

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Addresses < Rudy::CLI::Base

    
    def addresses_create
      puts "Create Address".bright, $/
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      address = radd.create
      puts address.to_s
    end
    
    def addresses_destroy_valid?
      raise "You have not supplied an IP addresses" unless @argv.ipaddress
      
      @radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      
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
      exit unless Annoy.are_you_sure?(:medium)
      
      execute_action { @radd.destroy(@argv.ipaddress) }
      
    end

    def associate_addresses_valid?
      raise "You have not supplied an IP addresses" unless @argv.ipaddress
      raise "You did not supply an instance ID" unless @argv.instanceid
      
      true
    end
    def associate_addresses
      puts "Associate Address".bright, $/
      
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      #@rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      #raise "Instance #{@argv.instid} does not exist!" unless @rinst.exists?(@argv.instid)

      raise "#{@argv.ipaddress} is not allocated to you" unless radd.exists?(@argv.ipaddress)
      raise "#{@argv.ipaddress} is already associated!" if radd.associated?(@argv.ipaddress)
      
      puts "Associating #{@argv.address} to #{@inst[:aws_groups]}: #{@inst[:dns_name]}"
      ret = radd.associate(@argv.ipaddress, @argv.instid)
      
    end
    
    def addresses
      puts "Addresses".bright, $/
      
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      addresses = radd.list || []
      
      addresses.each do |address|
        puts address.to_s
      end
      
      puts "No Addresses" if addresses.empty?
    end
    
    
  end

end; end
end; end

