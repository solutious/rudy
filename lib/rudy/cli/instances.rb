# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 

module Rudy
  module CLI
    class Instances < Rudy::CLI::Base
      
      def restart_instances_valid?
        raise "No instance ID provided" if @argv.filter.nil?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        
        @list = @ec2.instances.list(machine_group)
        raise "#{@argv.filter} is not in the current machine group" unless @list.has_key?(@argv.filter)
        
        raise "I will not help you destroy production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        
        exit unless are_you_sure?(5)
        true
      end
      def restart_instances
        puts "Restarting #{@argv.filter}!"
        @ec2.instances.restart @argv.filter
      end
      
      def instances
        filter = @argv.first
        filter = machine_group if filter.nil? && !@option.all
        if instance_id?(filter)
          inst = @ec2.instances.get(filter)
          raise "The instance #{filter} does not exist" if inst.empty?
          list = {inst[:aws_instance_id] => inst}
        else
          raise "The security group #{filter} does not exist" if filter && !@ec2.groups.exists?(filter)
          list = @ec2.instances.list(filter)
          if list.empty? 
            msg = "There are no instances running" 
            msg << " in the group #{filter}" if filter
            raise msg
          end
        end
        
        list.each_pair do |id, inst|
          print_instance inst
        end
        
      end
      
      def destroy_instances_valid?
        filter = argv.first
        raise "No instance ID provided" if filter.nil?
        raise "I will not help you destroy production!" if @global.environment == "prod" || filter =~ /^prod/
        exit unless are_you_sure?
        true
      end
        
      def destroy_instances
        filter = argv.first

        if @ec2.groups.exists?(filter)
          list = @ec2.instances.list(filter)
          raise "The group #{filter} has no running instances" if list.empty?
          instance = list.keys.first
        else 
          instance = filter
        end
        puts "Destroying #{instance}!"
        @ec2.instances.destroy instance
      end

    end
  end
end

