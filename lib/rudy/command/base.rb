
module Rudy
  class UnknownInstance < RuntimeError; end
end

module Rudy
  module Command
    class NoCred < RuntimeError; end;
    
    class Base < Drydock::Command

      attr_reader :scm
  
      attr_reader :rscripts
      attr_reader :domains
      attr_reader :machine_images
      
      attr_reader :config
      
      
      def init
        
        @config = Rudy::Config.new(:path => @global.config || RUDY_CONFIG_FILE, :verbose => (@global.verbose > 0) )
        
        raise "There is no machine group configured" if @config.machinegroup.nil?
        raise "There is no AWS info configured" if @config.awsinfo.nil?
        
        @global.accesskey ||= @config.awsinfo.accesskey || ENV['AWS_ACCESS_KEY']
        @global.secretkey ||= @config.awsinfo.secretkey || ENV['AWS_SECRET_KEY']
        @global.account ||= @config.awsinfo.account || ENV['AWS_ACCOUNT_NUMBER'] 
        
        @global.cert ||= @config.awsinfo.cert || ENV['EC2_CERT']
        @global.privatekey ||= @config.awsinfo.privatekey || ENV['EC2_PRIVATE_KEY']
        
        @global.cert = File.expand_path(@global.cert || '')
        @global.privatekey = File.expand_path(@global.privatekey || '')
        
        @global.region ||= @config.machinegroup.default_region || DEFAULT_REGION
        @global.zone ||= @config.machinegroup.default_zone || DEFAULT_ZONE
        @global.environment ||= @config.machinegroup.default_environment || DEFAULT_ENVIRONMENT
        @global.role ||= @config.machinegroup.default_role || DEFAULT_ROLE
        @global.position ||= @config.machinegroup.default_position || DEFAULT_POSITION
        @global.user ||= @config.machinegroup.default_user || DEFAULT_USER
        
        @global.local_user = ENV['USER'] || :user
        @global.local_hostname = Socket.gethostname || :host

        
        
        if @global.verbose > 1 && Drydock.debug?
          puts "GLOBALS:"
          @global.marshal_dump.each_pair do |n,v|
            puts "#{n}: #{v}"
          end
          puts "#{$/}CONFIG ([#{@global.environment}][#{@global.role}]):"
          val = @config.machinegroup.find_deferred(@global.environment, @global.role)
          y val
          puts
        end
        
        
        
        # TODO: enforce home directory permissions
        #if File.exists?(RUDY_CONFIG_DIR)
        #  puts "Checking #{check_environment} permissions..."
        #end
        
        if has_keys?
          @ec2 = Rudy::AWS::EC2.new(@global.accesskey, @global.secretkey)
          @sdb = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
          #@s3 = Rudy::AWS::SimpleDB.new(@global.accesskey, @global.secretkey)
        end
      end
      protected :init
      
      def machine_data
        machine_data = {
          # Give the machine an identity
          :zone => @global.zone,
          :environment => @global.environment,
          :role => @global.role,
          :position => @global.position,
          
          # Add hosts to the /etc/hosts file
          :hosts => {
            :dbmaster => "127.0.0.1",
          }
        } 
        
        machine_data.to_hash
      end
      
      
      # Raises exceptions if the requested user does 
      # not have a valid keypair configured. (See: EC2_KEYPAIR_*)
      def check_keys
        raise "No SSH key provided for #{keypairname}!" unless has_keypair?
        raise "SSH key provided but cannot be found! (#{keypairname}: #{keypairpath})" unless File.exists?(keypairpath)
      end  
      
      def has_pem_keys?
        (@global.cert       && File.exists?(@global.cert) && 
         @global.privatekey && File.exists?(@global.privatekey))
      end
       
      def has_keys?
        (@global.accesskey && @global.secretkey)
      end
      
      def keypairpath(name=nil)
        name ||= @global.user
        kp = @config.machinegroup.find_deferred(@global.environment, @global.role, :users, name, :keypair)
        kp &&= File.expand_path(kp)
        kp
      end
      def has_keypair?(name=nil)
        kp = keypairpath(name)
        (!kp.nil? && File.exists?(kp))
      end
      
      # Opens an SSH session. 
      # <li>+host+ the hostname to connect to. Defaults to the machine specified
      # by @global.environment, @global.role, @global.position.</li>
      # <li>+b+ a block to execute on the host. Receives |session|</li>
      # 
      #      ssh do |session|
      #        session.exec(cmd)
      #      end
      #
      # See Net::SSH
      #
      def ssh(host=nil, &b)
        host ||= machine_hostname
        raise "No host provided for SSH" unless host
        raise "No block provided for SSH" unless b
        
        Net::SSH.start(host, @global.user, :keys => [keypairpath]) do |session|
          b.call(session)
        end
      end
      
      # Secure copy. 
      # 
      #      scp do |scp|
      #        # upload a file to a remote server
      #        scp.upload! "/local/path", "/remote/path"
      #
      #        # upload from an in-memory buffer
      #        scp.upload! StringIO.new("some data to upload"), "/remote/path"
      #
      #        # run multiple downloads in parallel
      #        d1 = scp.download("/remote/path", "/local/path")
      #        d2 = scp.download("/remote/path2", "/local/path2")
      #        [d1, d2].each { |d| d.wait }
      #      end
      #
      def scp(host=nil, &b)
        host ||= machine_hostname
        raise "No host provided for SCP" unless host
        raise "No block provided for SCP" unless b
        
        Net::SCP.start(host, @global.user, :keys => [keypairpath]) do |scp|
          b.call(scp)
        end
      end
      
      # +name+ the name of the remote user to use for the remainder of the command
      # (or until switched again). If no name is provided, the user will be revert
      # to whatever it was before the previous switch. 
      def switch_user(name=nil)
        if name == nil && @switch_user_previous
          @global.user = @switch_user_previous
        elsif @global.user != name
          puts "Switching to #{name} user"
          @switch_user_previous = @global.user
          @global.user = name
        end
      end
      
      # Returns a hash of info for the requested machine. If the requested machine
      # is not running, it will raise an exception. 
      def find_current_machine
        find_machine(machine_group)
      end
        
      def find_machine(group)
        machine_list = @ec2.instances.list(group)
        machine = machine_list.values.first  # NOTE: Only one machine per group, for now...
        raise "There's no machine running in #{group}" unless machine
        raise "The primary machine in #{group} is not in a running state" unless machine[:aws_state] == 'running'
        machine
      end
      
      def machine_hostname(group=nil)
        group ||= machine_group
        find_machine(group)[:dns_name]
      end
      
      def machine_group
        [@global.environment, @global.role].join(RUDY_DELIM)
      end
      
      def machine_image
        ami = @config.machinegroup.find_deferred(@global.environment, @global.role, :ami)
        raise "There is no AMI configured for #{machine_group}" unless ami
        ami
      end
      
      def machine_address
        @config.machinegroup.find_deferred(@global.environment, @global.role, :address)
      end
      
      # TODO: fix machine_group to include zone
      def machine_name
        [@global.zone, machine_group, @global.position].join(RUDY_DELIM)
      end

      def instance_id?(id=nil)
        (id && id[0,2] == "i-")
      end
      
      def image_id?(id=nil)
        (id && id[0,4] == "ami-")
      end
      
      def volume_id?(id=nil)
        (id && id[0,4] == "vol-")
      end
      
      def snapshot_id?(id=nil)
        (id && id[0,5] == "snap-")
      end
      
      
      def do_dirty_disk_volume_deeds(disk, machine)
        puts "-"*30
        puts "Disk: #{disk.name} (path: #{disk.path}, device: #{disk.device})"
        puts 

        
        if !disk.awsid || (disk.awsid && !@ec2.volumes.exists?(disk.awsid))
          disk = Rudy::MetaData::Disk.update_volume(@sdb, @ec2, disk, machine)
        end
        
        raise "Unknown error creating volume! #{disk.awsid}" unless disk && disk.awsid
        
        
        if @ec2.instances.attached_volume?(machine[:aws_instance_id], disk.device)
          puts "#{disk.device} is already in use on #{machine[:aws_instance_id]}! Continuing..."
        else
          puts "Attaching #{disk.awsid} to #{machine[:aws_instance_id]}"
          @ec2.volumes.attach(machine[:aws_instance_id], disk.awsid, disk.device)
          sleep 2
        end

        @global.user = "root"
        
        if disk.raw_volume
          puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})"
          capture(:stdout) do
            ssh_command machine[:dns_name], keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
          end
          
          puts "Saving disk metadata"
          disk.raw_volume = false
          Rudy::MetaData::Disk.save(@sdb, disk)
          
          sleep 2
        end
        
        puts "Mounting #{disk.device} to #{disk.path}"
        capture(:stdout) do
          ssh_command machine[:dns_name], keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
        end
        sleep 1
        
      end
      
      
      
      # Print a default header to the screen for every command.
      # +cmd+ is the name of the command current running. 
      def print_header(cmd=nil)
        title = "RUDY v#{Rudy::VERSION}" unless @global.quiet
        now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
        criteria = []
        [:zone, :environment, :role, :position].each do |n|
          val = @global.send(n)
          next unless val
          criteria << "#{n.to_s.att :normal}:#{val.att :bright}"
        end
        puts '%s -- %s' % [title, criteria.join(", ")] unless @global.quiet

        puts unless @global.quiet
        
        if (@global.environment == "prod") 
          msg = %q(=======================================================
=======================================================
!!!!!!!!!   YOU ARE PLAYING WITH PRODUCTION   !!!!!!!!!
=======================================================
=======================================================)
          puts msg.colour(:red).bgcolour(:white).att(:bright), $/  unless @global.quiet
          
        end
        
        if Rudy.in_situ?
          msg = %q(============ THIS IS EC2 ============)
          puts msg.colour(:blue).bgcolour(:white).att(:bright), $/ unless @global.quiet
        end
        
      end
      
      def print_footer
        
      end
      


      
      def group_metadata(env=@global.environment, role=@global.role)
        query = "['environment' = '#{env}'] intersection ['role' = '#{role}']"
        @sdb.query_with_attributes(RUDY_DOMAIN, query)
      end
      
      private 
        # Print info about a running instance
        # +inst+ is a hash
        def print_instance(inst)
          puts '-'*60
          puts "Instance: #{inst[:aws_instance_id].att(:bright)} (AMI: #{inst[:aws_image_id]})"
          [:aws_state, :dns_name, :private_dns_name, :aws_availability_zone, :aws_launch_time, :ssh_key_name].each do |key|
             printf(" %22s: %s#{$/}", key, inst[key]) if inst[key]
           end
          printf(" %22s: %s#{$/}", 'aws_groups', inst[:aws_groups].join(', '))
          puts
        end
        
        def print_image(img)
          puts '-'*60
          puts "Image: #{img[:aws_id].att(:bright)}"
          img.each_pair do |key, value|
             printf(" %22s: %s#{$/}", key, value) if value
           end
          puts
        end
        
        def print_disk(disk, backups=[])
          puts '-'*60
          puts "Disk: #{disk.name.att(:bright)}"
          puts disk.to_s
          puts "#{backups.size} most recent backups:", backups.collect { |back| "#{back.nice_time} (#{back.awsid})" }
          puts
        end
        
        
        def print_volume(vol, disk)
          puts '-'*60
          puts "Volume: #{vol[:aws_id].att(:bright)} (disk: #{disk.name})"
          vol.each_pair do |key, value|
             printf(" %22s: %s#{$/}", key, value) if value
           end
          puts
        end
        
        # Print info about a a security group
        # +group+ is an OpenStruct
        def print_group(group)
          puts '-'*60
          puts "%12s: %s" % ['GROUP', group[:aws_group_name].att(:bright)]
          puts 
          
          group_ip = {}
          group[:aws_perms].each do |perm| 
             (group_ip[ perm[:cidr_ips] ] ||= []) << "#{perm[:protocol]}/#{perm[:from_port]}-#{perm[:to_port]}"
          end
           
          puts "%22s  %s" % ["source address/mask", "protocol/ports (from, to)"]
          
           
          group_ip.each_pair do |ip, perms|
            puts "%22s  %s" % [ip, perms.shift]
            perms.each do |perm|
              puts "%22s  %s" % ['', perm]
            end
            puts
          end
        end
        
      
    end
  end
end


__END__

@keypairs = {}
ENV.keys.select { |key| key.match /EC2_KEYPAIR/i }.each do |key|
  ec2, keypair, env, role, user = key.split '_' # EC2_KEYPAIR_STAGE_APP_RUDY
  raise "#{key} is malformed." unless env && role && user
  new_key = "#{env}-#{role}-#{user}".downcase
  @keypairs[new_key] = ENV[key]
end

@rscripts = {}
ENV.keys.select { |key| key.match /RUDY_RSCRIPT/i }.each do |key|
  rudy, rscript, env, role, user = key.split '_' # RUDY_RSCRIPT_STAGE_APP_ROOT
  raise "#{key} is malformed." unless env && role && user
  new_key = "#{env}-#{role}-#{user}".downcase
  @rscripts[new_key] = ENV[key]
end

@machine_images = {}
ENV.keys.select { |key| key.match /EC2_AMI_/i }.each do |key|
  ec2, ami, env, role = key.split '_' # RUDY_RSCRIPT_STAGE_APP_ROOT
  raise "#{key} is malformed." unless env && role
  new_key = "#{env}-#{role}".downcase
  @machine_images[new_key] = ENV[key]
end
