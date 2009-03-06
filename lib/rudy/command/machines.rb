

module Rudy
  module Command
    class Machines < Rudy::Command::Base
      
      def restart_machines_valid?
        @machine = find_current_machine
        raise "Please start an instance in #{machine_group} before releasing! (rudy -e #{@global.environment} instances -R)" unless @machine
      end
      
      
      def update_machines_valid?
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{@global.user}!" unless has_keypair?
        raise "No SSH key provided for root!" unless has_keypair?(:root)
        
        @script = File.join(RUDY_HOME, 'support', 'rudy-ec2-startup')
        
        raise "Cannot find startup script" unless File.exists?(@script)
        
        exit unless are_you_sure?
        
        true
      end
      

      def update_machines
        switch_user("root")
        
        scp do |scp|
          puts "Updating Rudy startup script (#{@script})"
          scp.upload!(@script, "/etc/init.d/") do |ch, name, sent, total|
            puts "#{name}: #{sent}/#{total}"
          end
          
        end
        
        ssh do |session|
          session.exec!("chmod 700 /etc/init.d/rudy-ec2-startup")
          puts "Installing Rudy (#{Rudy::VERSION})"
          puts session.exec!("gem sources -a http://gems.github.com")
          puts session.exec!("gem install --no-ri --no-rdoc solutious-rudy -v #{Rudy::VERSION}")
        end
      end
      
    end
  end
end