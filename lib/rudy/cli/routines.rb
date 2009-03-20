
module Rudy
  module CLI
    class Routines < Rudy::CLI::Base

    
    
      def startup_valid?
        true
      end
      def startup
        puts "Starting a machine group".bright
        opts = {}
        opts[:ami] = @option.image if @option.image
        opts[:group] = @option.group if @option.group
        #exit unless Annoy.are_you_sure?

        rroutine = Rudy::Routines::Startup.new(:config => @config, :global => @global)
        instances = rroutine.startup(opts)

        puts "Done!"
      end




      def restart_valid?
        shutdown_valid?
      end
      def restart
        puts "Restarting #{machine_group}: #{@list.keys.join(', ')}".bright
        switch_user("root")
        exit unless Annoy.are_you_sure?(:medium)

        @list.each do |id, inst|
          execute_routines(@list.values, :restart, :before)
        end

        puts "Restarting instances: #{@list.keys.join(', ')}".bright
        @ec2.instances.restart @list.keys
        sleep 10 # Wait for state to change and SSH to shutdown

        @list.keys.each do |id|
          wait_for_machine(id)
        end

        execute_disk_routines(@list.values, :restart)

        @list.each do |id, inst|
          execute_routines(@list.values, :restart, :after)
        end

        puts "Done!"
      end





      def shutdown_valid?
        raise "Cannot specify both instance ID and group name" if @argv.awsid && @option.group
        raise "I will not help you ruin production!" if @global.environment == "prod" # TODO: use_caution?, locked?
        true
      end
      def shutdown
        puts "Shutting down a machine group".bright
        opts = {}
        opts[:group] = @option.group if @option.group
        opts[:id] = @argv.awsid if @argv.awsid
        opts[:id] &&= [opts[:id]].flatten
      
        msg = opts[:id] ? "instances: #{opts[:id].join(', ')}" : (opts[:group] ? "group: #{opts[:group]}" : '')
        puts "This command also affects the disks on these machines! (according to your routines config)"
        exit unless Annoy.are_you_sure?(:medium)        # TODO: Check if instances are running before this
      
        rudy = Rudy::Machines.new(:config => @config, :global => @global)
        rudy.shutdown(opts)
      end
    end
  end
end