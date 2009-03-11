


module Rudy
  module Command
    class Groups < Rudy::Command::Base
      
      def groups(name=@argv.first)
        name = machine_group if name.nil? && !@option.all
        @ec2.groups.list(name).each do |grp|
          print_group grp
        end
      end
      
      def create_groups(name=@argv.first)
        name ||= machine_group
        puts "Creating group #{name}"
        raise "The group #{name} already exists" if @ec2.groups.exists?(name)

        @ec2.groups.create(name)
        
        modify_groups name
      end
      
      def modify_groups(name=@argv.first)
        name ||= machine_group
        raise "The group #{name} does not exist" unless @ec2.groups.exists?(name)
        
        @option.addresses ||= [Rudy::Utils::external_ip_address]
        @option.ports ||= [22,80,443]
        @option.protocols ||= ["tcp"]
        
        # Make sure the IP addresses have ranges
        @option.addresses.collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32"  }
        
        @option.protocols.each do |protocol|
          puts "Adding ports #{@option.ports.join(',')} (#{protocol}) for #{@option.addresses.join(', ')}"
          @option.addresses.each do |address|
            @option.ports.each do |port|
              @ec2.groups.modify(name, port, port, protocol, address)
            end
          end
        end
        
        groups name
      end
      
      def destroy_groups(name=@argv.first)
        name ||= machine_group
        puts "Destroying group #{name}"
        name = machine_group if name.nil?
        raise "The group #{name} does not exist" unless @ec2.groups.exists?(name)
        exit unless are_you_sure?
        
        @ec2.groups.destroy(name)
        
      end
    end
  end
end

