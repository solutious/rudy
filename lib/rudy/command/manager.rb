

module Rudy
  class Manager
    include Rudy::Huxtable
    
    def create_domain(name)
      @sdb.domains.create(name)
    end
    
    def domains
      (@sdb.domains.list || []).flatten
    end
    
    
    
    
    
    
    def update_valid?
      raise "No EC2 .pem keys provided" unless has_pem_keys?
      raise "No SSH key provided for #{@global.user}!" unless has_keypair?
      raise "No SSH key provided for root!" unless has_keypair?(:root)
      
      @option.group ||= machine_group
      
      @scripts = %w[rudy-ec2-startup update-ec2-ami-tools randomize-root-password]
      @scripts.collect! {|script| File.join(RUDY_HOME, 'support', script) }
      @scripts.each do |script| 
        raise "Cannot find #{script}" unless File.exists?(script)
      end
      
      true
    end
    
    def update
      puts "Updating Rudy on machines in #{@option.group}"
      switch_user("root")
      
      exit unless Annoy.are_you_sure?
      scp do |scp|
        @scripts.each do |script|
          puts "Uploading #{File.basename(script)}"
          scp.upload!(script, "/etc/init.d/")
        end
      end
      
      ssh do |session|
        @scripts.each do |script|
          session.exec!("chmod 700 /etc/init.d/#{File.basename(script)}")
        end
        
        puts "Installing Rudy (#{Rudy::VERSION})"
        session.exec!("mkdir -p /etc/ec2")
        session.exec!("gem sources -a http://gems.github.com")
        puts session.exec!("gem install --no-ri --no-rdoc rudy -v #{Rudy::VERSION}")
      end
    end


  end
end