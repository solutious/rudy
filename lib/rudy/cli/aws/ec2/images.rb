

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Images < Rudy::CLI::CommandBase
    
    #def print_header
    #  puts @global.print_header, @@global.print_header
    #end
    
    
    def images_valid?
      if @option.owner == 'self'
        raise "AWS_ACCOUNT_NUMBER not set" unless @@global.accountnum 
        @option.owner = @@global.accountnum 
      end
      
      true  
    end
    def images
      
      rimages = Rudy::AWS::EC2::Images.new(@@global.accesskey, @@global.secretkey, @@global.region)
      unless @option.all
        @option.owner ||= 'amazon' 
        puts "Images owned by #{@option.owner.bright}" unless @argv.awsid
      end
      
      images = rimages.list(@option.owner, @argv) || []
      images.each do |img|
        puts @@global.verbose > 0 ? img.inspect : img.dump(@@global.format)
      end
      puts "No images" if images.empty?
    end

    def prepare_images_valid?
      true
    end
    def prepare_images
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all
      opts[:id] = @option.instid if @option.instid
      
      puts "This will do the following:"
      puts "- Clear bash history"
      # NOTE: We can't delete the host keys here. Otherwise we can't create the image. 
      #puts "- Delete host SSH keys (this is permanent!)"
      puts "" 
      
      # Options to be sent to Net::SSH
      ssh_opts = { :user => @global.user || Rudy.sysinfo.user, :debug => STDERR  }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        ssh_opts[:keys] = @@global.pkey 
      end
      
      execute_check(:medium)
      
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        puts "Preparing #{inst.dns_public}..."
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
        rbox.safe = false
        # We need to explicitly add the rm command for rbox so we
        # can delete the SSH host keys. This is will force the instance
        # to re-create it's SSH keys on first boot.
        def rbox.rm(*args); cmd('rm', args); end
        p ret = rbox.history(:c)
        p ret.exit_code
        p ret.stderr
        p ret.stdout
        
      end
      
      puts "done"
    end
    
    def create_images_valid?
      raise "No account number" unless @@global.accountnum
      raise "No Amazon cert-***.pem" unless @@global.cert
      raise "No Amazon pk-***.pem" unless @@global.privatekey
      true
    end
    
    def create_images
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all
      opts[:id] = @option.instid if @option.instid
      
      puts "You may want to run rudy-ec2 #{@alias} --prepare before this.".color(:blue)
      puts "This feature is experimental. Make sure you enter the bucket"
      puts "and image names correctly because if they're wrong the image"
      puts "won't get created and you'll be annoyed that you waited."
      
      # Options to be sent to Net::SSH
      ssh_opts = { :user => @global.user || Rudy.sysinfo.user, :debug => STDERR  }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        ssh_opts[:keys] = @@global.pkey 
      end
      
      unless @option.name
        print "Enter the image name: "
        @option.image_name = gets.chomp
      end

      unless @option.bucket
        print "Enter the S3 bucket that will store the image: "
        @option.bucket_name = gets.chomp
      end
      
      execute_check(:medium)
      
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        puts inst.dns_public
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
        
        # TODO: Replace with rbox.upload
        
        # ~/.rudy, /etc/motd, history -c, /etc/hosts, /var/log/rudy*
        cert = File.read(@@global.cert)
        pk = File.read(@@global.privatekey)
        rbox.safe = false
        rbox.echo("'#{cert}' > /mnt/cert-temporary.pem")
        rbox.echo("'#{pk}' > /mnt/pk-temporary.pem")
        rbox.safe = true
        rbox.touch("/root/firstrun")
        
        # TODO: 
        # We have to delete the host keys just before we run the bundle command. 
        # The problem is that if we lose the connection we won't be able to connect
        # to the instance again. A better solution is to ass the keys to the ignore
        # list for the bundle command. 
        
        #ret = rbox.rm('/etc/ssh/ssh_host_*_key*')
        #puts "Starting bundling process...".bright
        #puts ssh_command(machine[:dns_name], keypairpath, @global.user, "ec2-bundle-vol -r i386 -p #{@option.image_name} -k /mnt/pk-*pem -c /mnt/cert*pem -u #{@option.account}", @option.print)
        #puts ssh_command(machine[:dns_name], keypairpath, @global.user, "ec2-upload-bundle -b #{@option.bucket_name} -m /tmp/#{@option.image_name}.manifest.xml -a #{@global.accesskey} -s #{@global.secretkey}", @option.print)
        #
        #@ec2.images.register("#{@option.bucket_name}/#{@option.image_name}.manifest.xml") unless @option.print
        
        break
      end
      
    end
    
   #def create_images_valid?
   #  puts "Make sure the machine is clean. I don't want archive no crud!"
   #  switch_user("root")
   #  
   #    raise "No EC2 .pem keys provided" unless has_pem_keys?
   #    raise "No SSH key provided for #{@global.user}!" unless has_keypair?
   #    raise "No SSH key provided for root!" unless has_keypair?(:root)
   #  true
   #end
   #
   #
   #def prepare_images
   #  # TODO: Avail hooks for clean an instance
   #  # Clean off Rudy specific crap. 
   #end
   #
   #
   
   #
   #def deregister
   #  ami = @argv.first
   #  raise "You must supply an AMI ID (ami-XXXXXXX)" unless ami
   #  puts "Deregistering AMI: #{ami}"
   #  
   #  exit unless Annoy.are_you_sure?
   #  
   #  if @ec2.images.deregister(ami)
   #    puts "Done!"
   #  else
   #    puts "There was an unknown problem!"
   #  end
   #  
   #end

  end


end; end
end; end


