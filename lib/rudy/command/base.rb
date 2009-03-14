
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
        
        
        raise "PRODUCTION ACCESS IS DISABLED IN DEBUG MODE" if @global.environment == "prod" && Drydock.debug?
        
        @global.config ||= RUDY_CONFIG_FILE
        
        unless File.exists?(@global.config)
          init_config_dir
        end
        
        @config = Rudy::Config.new(@global.config, {:verbose => (@global.verbose > 0)} )
        @config.look_and_load
        
        raise "There is no machine group configured" if @config.machines.nil?
        raise "There is no AWS info configured" if @config.awsinfo.nil?
        
        
        @global.accesskey ||= @config.awsinfo.accesskey || ENV['AWS_ACCESS_KEY']
        @global.secretkey ||= @config.awsinfo.secretkey || ENV['AWS_SECRET_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
        @global.account ||= @config.awsinfo.account || ENV['AWS_ACCOUNT_NUMBER'] 
        
        @global.cert ||= @config.awsinfo.cert || ENV['EC2_CERT']
        @global.privatekey ||= @config.awsinfo.privatekey || ENV['EC2_PRIVATE_KEY']
        
        @global.cert = File.expand_path(@global.cert || '')
        @global.privatekey = File.expand_path(@global.privatekey || '')
        
        @global.region ||= @config.defaults.region || DEFAULT_REGION
        @global.zone ||= @config.defaults.zone || DEFAULT_ZONE
        @global.environment ||= @config.defaults.environment || DEFAULT_ENVIRONMENT
        @global.role ||= @config.defaults.role || DEFAULT_ROLE
        @global.position ||= @config.defaults.position || DEFAULT_POSITION
        @global.user ||= @config.defaults.user || DEFAULT_USER
        
        @global.local_user = ENV['USER'] || :user
        @global.local_hostname = Socket.gethostname || :host
        
        
        if @global.verbose > 1
          puts "GLOBALS:"
          @global.marshal_dump.each_pair do |n,v|
            puts "#{n}: #{v}"
          end
          ["machines", "routines"].each do |type|
            puts "#{$/*2}#{type.upcase}:"
            val = @config.send(type).find_deferred(@global.environment, @global.role)
            puts val.to_hash.to_yaml
          end
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
        raise "No SSH key provided for #{@global.user}! (check #{RUDY_CONFIG_FILE})" unless has_keypair?
        raise "SSH key provided but cannot be found! (check #{RUDY_CONFIG_FILE})" unless File.exists?(keypairpath)
      end  
      
      def has_pem_keys?
        (@global.cert       && File.exists?(@global.cert) && 
         @global.privatekey && File.exists?(@global.privatekey))
      end
       
      def has_keys?
        (@global.accesskey && !@global.accesskey.empty? && @global.secretkey && !@global.secretkey.empty?)
      end
      
      def keypairpath(name=nil)
        name ||= @global.user
        raise "No default user configured" unless name
        kp = @config.machines.find(@global.environment, @global.role, :users, name, :keypair2)
        kp ||= @config.machines.find(@global.environment, :users, name, :keypair)
        kp ||= @config.machines.find(:users, name, :keypair)
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
        raise "No host provided for scp" unless host
        raise "No block provided for scp" unless b
        
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
          puts "Remote commands will be run as #{name} user"
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
        ami = @config.machines.find_deferred(@global.environment, @global.role, :ami)
        raise "There is no AMI configured for #{machine_group}" unless ami
        ami
      end
      
      def machine_address
        @config.machines.find_deferred(@global.environment, @global.role, :address)
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
      
      
      def wait_for_machine(id)
        
        print "Waiting for #{id} to become available"
        STDOUT.flush
        
        while @ec2.instances.pending?(id)
          sleep 2
          print '.'
          STDOUT.flush
        end
        
        machine = @ec2.instances.get(id)
        
        puts " It's up!\a\a" # with bells
        print "Waiting for SSH daemon at #{machine[:dns_name]}"
        STDOUT.flush
        
        while !Rudy::Utils.service_available?(machine[:dns_name], 22)
          print '.'
          STDOUT.flush
        end
        puts " It's up!\a\a\a"

      end
      
      
      def device_to_path(machine, device)
        # /dev/sdr            10321208    154232   9642688   2% /rilli/app
        dfoutput = ssh_command(machine[:dns_name], keypairpath, @global.user, "df #{device} | tail -1").chomp
        dfvals = dfoutput.scan(/(#{device}).+\s(.+?)$/).flatten  # ["/dev/sdr", "/rilli/app"]
        dfvals.last
      end
      
      # +action+ is one of: :shutdown, :start, :deploy
      # +machine+ is a right_aws machine instance hash
      def execute_disk_routines(machines, action)
        machines = [machines] unless machines.is_a?( Array)
        
        puts "Running #{action.to_s.capitalize} DISK routines".att(:bright)
        
        disks = @config.machines.find_deferred(@global.environment, @global.role, :disks)
        routines = @config.routines.find(@global.environment, @global.role, action, :disks)
        
        unless routines
          puts "No #{action} disk routines."
          return
        end
        
        switch_user("root")
        
        machines.each do |machine|

          unless machine[:aws_instance_id]
            puts "Machine given has no instance ID. Skipping disks."
            return
          end
        
          unless machine[:dns_name]
            puts "Machine given has no DNS name. Skipping disks."
            return
          end
          
          if routines.destroy
            disk_paths = routines.destroy.keys
            vols = @ec2.instances.volumes(machine[:aws_instance_id]) || []
            puts "No volumes to destroy for (#{machine[:aws_instance_id]})" if vols.empty?
            vols.each do |vol|
              disk = Rudy::MetaData::Disk.find_from_volume(@sdb, vol[:aws_id])
              if disk
                this_path = disk.path
              else
                puts "No disk metadata for volume #{vol[:aws_id]}. Going old school..."
                this_path = device_to_path(machine, vol[:aws_device])
              end
              
              dconf = disks[this_path]
              
              unless dconf
                puts "#{this_path} is not defined for this machine. Check your machines config."
                next
              end
              
              if disk_paths.member?(this_path) 
              
                unless disks.has_key?(this_path)
                  puts "#{this_path} is not defined as a machine disk. Skipping..."
                  next
                end
                
                begin
                  puts "Unmounting #{this_path}..."
                  ssh_command machine[:dns_name], keypairpath, @global.user, "umount #{this_path}"
                  sleep 3
                rescue => ex
                  puts "Error while unmounting #{this_path}: #{ex.message}"
                  puts ex.backtrace if Drydock.debug?
                  puts "We'll keep going..."
                end
                
                begin
                  
                  if @ec2.volumes.attached?(disk.awsid)
                    puts "Detaching #{vol[:aws_id]}"
                    @ec2.volumes.detach(vol[:aws_id])
                    sleep 3 # TODO: replace with something like wait_for_machine
                  end
                  
                  puts "Destroying #{this_path} (#{vol[:aws_id]})"
                  if @ec2.volumes.available?(disk.awsid)
                    @ec2.volumes.destroy(vol[:aws_id])
                  else
                    puts "Volume is still attached (maybe a web server of database is running?)"
                  end
                  
                  if disk
                    puts "Deleteing metadata for #{disk.name}"
                    Rudy::MetaData::Disk.destroy(@sdb, disk)
                  end
                
                rescue => ex
                  puts "Error while detaching volume #{vol[:aws_id]}: #{ex.message}"
                  puts ex.backtrace if Drydock.debug?
                  puts "Continuing..."
                end
                
              end
              puts
              
            end
          
          end
          
          
          if routines.mount
            disk_paths = routines.mount.keys
            vols = @ec2.instances.volumes(machine[:aws_instance_id]) || []
            puts "No volumes to mount for (#{machine[:aws_instance_id]})" if vols.empty?
            vols.each do |vol|
              disk = Rudy::MetaData::Disk.find_from_volume(@sdb, vol[:aws_id])
              if disk
                this_path = disk.path
              else
                puts "No disk metadata for volume #{vol[:aws_id]}. Going old school..."
                this_path = device_to_path(machine, vol[:aws_device])
              end
              
              next unless disk_paths.member?(this_path)
                
              dconf = disks[this_path]
              
              unless dconf
                puts "#{this_path} is not defined for this machine. Check your machines config."
                next
              end
              
              
              begin
                unless @ec2.instances.attached_volume?(machine[:aws_instance_id], vol[:aws_device])
                  puts "Attaching #{vol[:aws_id]} to #{machine[:aws_instance_id]}".att(:bright)
                  @ec2.volumes.attach(machine[:aws_instance_id], vol[:aws_id],vol[:aws_device])
                  sleep 3
                end

                puts "Mounting #{this_path} to #{vol[:aws_device]}".att(:bright)
                ssh_command machine[:dns_name], keypairpath, @global.user, "mkdir -p #{this_path} && mount -t ext3 #{vol[:aws_device]} #{this_path}"

                sleep 1
              rescue => ex
                puts "There was an error mounting #{this_path}: #{ex.message}"
                puts ex.backtrace if Drydock.debug?
              end
              puts 
            end
          end
        
        
          
          if routines.restore
            
            routines.restore.each_pair do |path,props|
              from = props[:from] || "unknown"
              unless from.to_s == "backup"
                puts "Sorry! You can currently only restore from backup. Check your routines config."
                next
              end
              
              begin 
                puts "Restoring disk for #{path}"
                
                dconf = disks[path]
                
                unless dconf
                  puts "#{path} is not defined for this machine. Check your machines config."
                  next
                end
                    
                zon = props[:zone] || @global.zone
                env = props[:environment] || @global.environment
                rol = props[:role] || @global.role
                pos = props[:position] || @global.position
                puts "Looking for backup from #{zon}-#{env}-#{rol}-#{pos}"
                backup = find_most_recent_backup(zon, env, rol, pos, path)
                
                unless backup
                  puts "No backups found"
                  next
                end
                
                puts "Found: #{backup.name}".att(:bright)
                
                disk = Rudy::MetaData::Disk.new
                disk.path = path
                [:region, :zone, :environment, :role, :position].each do |n|
                  disk.send("#{n}=", @global.send(n)) if @global.send(n)
                end
                
                disk.device = dconf[:device]
                size = (backup.size.to_i > dconf[:size].to_i) ? backup.size : dconf[:size]
                disk.size = size.to_i
                
                
                if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
                  puts "The disk #{disk.name} already exists."
                  puts "You probably need to define when to destroy the disk."
                  puts "Skipping..."
                  next
                end

                if @ec2.instances.attached_volume?(machine[:aws_instance_id], disk.device)
                  puts "Skipping disk for #{disk.path} (device #{disk.device} is in use)"
                  next
                end

                # NOTE: It's important to use Caesars' hash syntax b/c the disk property
                # "size" conflicts with Hash#size which is what we'll get if there's no 
                # size defined. 
                unless disk.size.kind_of?(Integer)
                  puts "Skipping disk for #{disk.path} (size not defined)"
                  next
                end

                if disk.path.nil?
                  puts "Skipping disk for #{disk.path} (no path defined)"
                  next
                end

                unless disk.valid?
                  puts "Skipping #{disk.name} (not enough info)"
                  next
                end

                puts "Creating volume... (from #{backup.awsid})".att(:bright)
                volume = @ec2.volumes.create(@global.zone, disk.size, backup.awsid)

                puts "Attaching #{volume[:aws_id]} to #{machine[:aws_instance_id]}".att(:bright)
                @ec2.volumes.attach(machine[:aws_instance_id], volume[:aws_id], disk.device)
                sleep 3

                puts "Mounting #{disk.device} to #{disk.path}".att(:bright)
                ssh_command machine[:dns_name], keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"

                puts "Creating disk metadata for #{disk.name}"
                disk.awsid = volume[:aws_id]
                Rudy::MetaData::Disk.save(@sdb, disk)

                sleep 1
              rescue => ex
                puts "There was an error creating #{path}: #{ex.message}"
                puts ex.backtrace if Drydock.debug?
                if disk
                  puts "Removing metadata for #{disk.name}"
                  Rudy::MetaData::Disk.destroy(@sdb, disk)
                end
              end
              puts
            end
          end
          
          
          
          if routines.create
            routines.create.each_pair do |path,props|
        
              begin 
                puts "Creating disk for #{path}"
                
                dconf = disks[path]

                unless dconf
                  puts "#{path} is not defined for this machine. Check your machines config."
                  next
                end
                
                disk = Rudy::MetaData::Disk.new
                disk.path = path
                [:region, :zone, :environment, :role, :position].each do |n|
                  disk.send("#{n}=", @global.send(n)) if @global.send(n)
                end
                [:device, :size].each do |n|
                  disk.send("#{n}=", dconf[n]) if dconf.has_key?(n)
                end
            
                if Rudy::MetaData::Disk.is_defined?(@sdb, disk)
                  puts "The disk #{disk.name} already exists."
                  puts "You probably need to define when to destroy the disk."
                  puts "Skipping..."
                  next
                end
            
                if @ec2.instances.attached_volume?(machine[:aws_instance_id], disk.device)
                  puts "Skipping disk for #{disk.path} (device #{disk.device} is in use)"
                  next
                end
            
                # NOTE: It's important to use Caesars' hash syntax b/c the disk property
                # "size" conflicts with Hash#size which is what we'll get if there's no 
                # size defined. 
                unless disk.size.kind_of?(Integer)
                  puts "Skipping disk for #{disk.path} (size not defined)"
                  next
                end
            
                if disk.path.nil?
                  puts "Skipping disk for #{disk.path} (no path defined)"
                  next
                end
            
                unless disk.valid?
                  puts "Skipping #{disk.name} (not enough info)"
                  next
                end
                        
                puts "Creating volume... (#{disk.size}GB in #{@global.zone})".att(:bright)
                volume = @ec2.volumes.create(@global.zone, disk.size)
            
                puts "Attaching #{volume[:aws_id]} to #{machine[:aws_instance_id]}".att(:bright)
                @ec2.volumes.attach(machine[:aws_instance_id], volume[:aws_id], disk.device)
                sleep 6
                
                puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".att(:bright)
                ssh_command machine[:dns_name], keypairpath, @global.user, "mkfs.ext3 -F #{disk.device}"
                sleep 3
                
                puts "Mounting #{disk.device} to #{disk.path}".att(:bright)
                ssh_command machine[:dns_name], keypairpath, @global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
              
                puts "Creating disk metadata for #{disk.name}"
                disk.awsid = volume[:aws_id]
                Rudy::MetaData::Disk.save(@sdb, disk)
              
                sleep 1
              rescue => ex
                puts "There was an error creating #{path}: #{ex.message}"
                if disk
                  puts "Removing metadata for #{disk.name}"
                  Rudy::MetaData::Disk.destroy(@sdb, disk)
                end
              end
              puts
            end
          end
        end
      end
      
      def find_most_recent_backup(zon, env, rol, pos, path)
        criteria = [zon, env, rol, pos, path]
        (Rudy::MetaData::Backup.list(@sdb, *criteria) || []).first
      end
      
      def execute_routines(machines, action, before_or_after)
        machines = [machines] unless machines.is_a?( Array)
        config = @config.routines.find_deferred(@global.environment, @global.role, :config) || {}        
        config[:global] = @global.marshal_dump
        config[:global].reject! { |n,v| n == :cert || n == :privatekey }
        
        # The config file contains settings from ~/.rudy/config 
        #
        #     routines do 
        #       config do
        #       end
        #     end
        #
        config_file = "#{action}-config.yaml"
        tf = Tempfile.new(config_file)
        write_to_file(tf.path, config.to_hash.to_yaml, 'w')
        puts "Running #{action.to_s.capitalize} #{before_or_after.to_s.upcase} routines".att(:bright)
        machines.each do |machine|
          
          rscripts = @config.routines.find_deferred(@global.environment, @global.role, action, before_or_after) || []
          rscripts = [rscripts] unless rscripts.is_a?(Array)
          
          puts "No scripts defined." if !rscripts || rscripts.empty?
          
          rscripts.each do |rscript|
            user, script = rscript.shift
            
            switch_user(user) # scp and ssh will run as this user
        
            puts "Transfering #{config_file}..."
            scp do |scp|
              scp.upload!(tf.path, "~/#{config_file}") do |ch, name, sent, total|
                "#{name}: #{sent}/#{total}"
              end
            end
            ssh do |session|
              puts "Running #{script}...".att(:bright)
              session.exec!("chmod 700 ~/#{config_file}")
              session.exec!("chmod 700 #{script}")
              puts session.exec!("#{script}")
          
              puts "Removing remote copy of #{config_file}..."
              session.exec!("rm ~/#{config_file}")
            end
            puts $/
          end
        end
        
        tf.delete     # remove local copy of config_file
        #switch_user   # return to the requested user
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
          criteria << "#{n.to_s.slice(0,1).att :normal}:#{val.att :bright}"
        end
        puts '%s -- %s UTC' % [title, now_utc] unless @global.quiet
        puts '[%s]' % criteria.join("  ") unless @global.quiet
        
        puts unless @global.quiet
        
        if (@global.environment == "prod") 
          msg = without_indent %q(
          =======================================================
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
          puts "Volume: #{vol[:aws_id].att(:bright)} (disk: #{disk.name if disk})"
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
        
        def init_config_dir
          unless File.exists?(RUDY_CONFIG_DIR)
            puts "Creating #{RUDY_CONFIG_DIR}"
            Dir.mkdir(RUDY_CONFIG_DIR, 0700)
          end

          unless File.exists?(RUDY_CONFIG_FILE)
            puts "Creating #{RUDY_CONFIG_FILE}"
            rudy_config = without_indent %Q{
              # Amazon Web Services 
              # Account access indentifiers.
              awsinfo do
                account ""
                accesskey ""
                secretkey ""
                privatekey "~/path/2/pk-xxxx.pem"
                cert "~/path/2/cert-xxxx.pem"
              end
              
              # Machine Configuration
              # Specify your private keys here. These can be defined globally
              # or by environment and role like in machines.rb.
              machines do
                users do
                  root :keypair => "path/2/root-private-key"
                end
              end
              
              # Routine Configuration
              # Define stuff here that you don't want to be stored in version control. 
              routines do
                config do 
                  # ...
                end
              end

              # Global Defaults 
              # Define the values to use unless otherwise specified on the command-line. 
              defaults do
                region "us-east-1" 
                zone "us-east-1b"
                environment "stage"
                role "app"
                position "01"
                user ENV['USER']
              end
            }
            write_to_file(RUDY_CONFIG_FILE, rudy_config, 'w')
          end

          #puts "Creating SimpleDB domain called #{RUDY_DOMAIN}"
          #@sdb.domains.create(RUDY_DOMAIN)
        end
    end
  end
end


