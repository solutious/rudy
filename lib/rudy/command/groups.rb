


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
        raise "Group already exists" if @ec2.groups.exists?(@argv.name)
        
        @ec2.groups.create(@argv.name)
        
        authorize_group
      end
      
      def authorize_group(action=:authorize)
        @argv.name ||= machine_group
        puts "#{action.to_s.capitalize} access for #{@argv.name}"
        raise "Group does not exist" unless @ec2.groups.exists?(@argv.name)
        
        if @option.group || @option.owner
          
          unless @option.owner
            @option.owner ||= @config.awsinfo.account
            puts "Owner not specified. Using: #{@option.owner}"
          end
          
          if @option.addresses || @option.ports || @option.protocol
            raise "When you supply a group/owner, you must not supply port or IP address"
          end
          
          raise "You must supply a group name" unless @option.group
          raise "You must supply an owner ID" unless @option.owner
          
          @ec2.groups.send(action, @argv.name, nil, nil, nil, nil, @option.group, @option.owner)
        else
          @option.ports.collect! { |port| port.split(/:/) }
          @option.ports ||= [[22,22],[80,80],[443,443]]
          @option.protocols ||= ["tcp"]          
          @option.addresses ||= [Rudy::Utils::external_ip_address]
          
          # Make sure the IP addresses have ranges
          @option.addresses.collect! { |ip| (ip.match /\/\d+/) ? ip : "#{ip}/32"  }
        
          @option.protocols.each do |protocol|
            @option.addresses.each do |address|
              @option.ports.each do |port|
                puts "Ports #{port[0]}:#{port[1]} (#{protocol}) for #{@option.addresses.join(', ')}"
                @ec2.groups.send(action, @argv.name, port[0].to_i, (port[1] || port[0]).to_i, protocol, address, @option.group, @option.owner)
              end
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

