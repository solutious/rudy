


module Rudy
  module Command
    class Groups < Rudy::Command::Base
      
      def group
        @argv.name ||= machine_group if name.nil? && !@option.all
        @argv.name ||= []
        @ec2.groups.list(@argv.name).each do |grp|
          puts '-'*60
          puts grp.to_s
        end
      end
      
      def create_group
        @argv.name ||= machine_group
        puts "Creating group: #{@argv.name}"
        abort "Group already exists" if @ec2.groups.exists?(@argv.name)

        @ec2.groups.create(@argv.name)
        
        modify_group
      end
      
      def authorize_group(action=:authorize)
        @argv.name ||= machine_group
        puts "#{action.to_s.capitalize} group: #{@argv.name}"
        raise "Group does not exist" unless @ec2.groups.exists?(@argv.name)
        
        @option.addresses ||= [Rudy::Utils::external_ip_address]
        @option.ports ||= [22,80,443]
        @option.protocols ||= ["tcp"]
        
        # Make sure the IP addresses have ranges
        @option.addresses.collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32"  }
        
        @option.protocols.each do |protocol|
          puts "Ports #{@option.ports.join(',')} (#{protocol}) for #{@option.addresses.join(', ')}"
          @option.addresses.each do |address|
            @option.ports.each do |port|
              @ec2.groups.send(action, @argv.name, port, port, protocol, address)
            end
          end
        end
        
        puts '-'*60
        puts @ec2.groups.get(@argv.name).to_s
      end
      
      def revoke_group
        authorize_group(:revoke)
      end
      
      def destroy_group(name=@argv.first)
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

