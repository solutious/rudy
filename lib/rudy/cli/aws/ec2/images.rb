

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Images < Rudy::CLI::CommandBase
    
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

    ##def prepare_images_valid?
    ##  true
    ##end
    ##def prepare_images
    ##  opts = {}
    ##  opts[:id] = @option.instid if @option.instid
    ##  
    ##  puts "This will do the following:"
    ##  puts "- Clear bash history"
    ##  # NOTE: We can't delete the host keys here. Otherwise we can't create the image. 
    ##  #puts "- Delete host SSH keys (this is permanent!)"
    ##  puts "" 
    ##  
    ##  ## TODO:       
    ##  ## ~/.rudy, /etc/motd, history -c, /etc/hosts, /var/log/rudy*
    ##  
    ##  execute_check(:medium)
    ##  
    ##
    ##  # Options to be sent to Net::SSH
    ##  ssh_opts = { :user => @global.user || Rudy.sysinfo.user, :debug => STDERR  }
    ##  if @@global.pkey 
    ##    raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
    ##    raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
    ##    ssh_opts[:keys] = @@global.pkey 
    ##  end
    ##  
    ##  
    ##  rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
    ##  lt = rudy.list_group(nil, :running, opts[:id]) do |inst|
    ##    
    ##    puts "Preparing #{inst.dns_public}..."
    ##    
    ##    # Open the connection and run the command
    ##    rbox = Rye::Box.new(inst.dns_public, ssh_opts)
    ##    
    ##    # We need to explicitly add the rm command for rbox so we
    ##    # can delete the SSH host keys. This is will force the instance
    ##    # to re-create it's SSH keys on first boot.
    ##    def rbox.rm(*args); cmd('rm', args); end
    ##    p ret = rbox.history(:c)
    ##    p ret.exit_code
    ##    p ret.stderr
    ##    p ret.stdout
    ##    
    ##  end
    ##  
    ##  puts "done"
    ##end
    
    def create_images_valid?
      raise "No account number" unless @@global.accountnum
      raise "No Amazon cert-***.pem" unless @@global.cert
      raise "No Amazon pk-***.pem" unless @@global.privatekey
      raise "You must supply a root keypair path" unless @@global.pkey
      
      @rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      @rimages = Rudy::AWS::EC2::Images.new(@@global.accesskey, @@global.secretkey, @@global.region)
      @s3 = Rudy::AWS::S3.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise "No instances" unless @rinst.any?
      raise "You must supply an S3 bucket name. See: 'rudy-s3 buckets'" unless @option.bucket
      raise "You must supply an image name" unless @option.name
      raise "The bucket '#{@option.bucket}' does not exist" unless @s3.bucket_exists?(@option.bucket)
      true
    end
    
    def create_images
      opts = {}
      opts[:id] = @option.instid if @option.instid
      
      @@global.user = 'root'
      
      puts "You may want to run rudy-ec2 #{@alias} --prepare first".bright
      puts "NOTE 1: This process is currently Linux-only"
      puts "NOTE 2: If you plan to create a public machine image, there are "
      puts "additional steps to take to remove any sensitive information"
      puts "before creating the image. See:"
      puts "http://docs.amazonwebservices.com/AWSEC2/latest/DeveloperGuide/AESDG-chapter-sharingamis.html"
      exit unless Annoy.pose_question("  Continue?\a ", /yes|y|ya|sure|you bet!/i, STDERR)

      # Options to be sent to Net::SSH
      ssh_opts = { :user => @@global.user || Rudy.sysinfo.user, :debug => nil  }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        ssh_opts[:keys] = @@global.pkey 
      end
      
      lt = @rinst.list_group(nil, :running, opts[:id]) do |inst|
        
        puts inst.to_s
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
        def rbox.bundle_vol(*args); cmd('ec2-bundle-vol', args); end
        def rbox.upload_vol(*args); cmd('ec2-upload-bundle', args); end

        rbox.upload(@@global.cert, @@global.privatekey, "/mnt")
        rbox.touch("/root/firstrun")
        
        ## TODO: 
        ## We have to delete the host keys just before we run the bundle command. 
        ## The problem is that if we lose the connection we won't be able to connect
        ## to the instance again. A better solution is to add the keys to the ignore
        ## list for the bundle command. 
        ##ret = rbox.rm('/etc/ssh/ssh_host_*_key*')

        puts "Starting bundling process..."
        
        pkeyfile = File.basename(@@global.privatekey)
        certfile = File.basename(@@global.cert)
        
        rbox.bundle_vol(:r, "i386", :p, @option.name, :k, "/mnt/#{pkeyfile}", :c, "/mnt/#{certfile}", :u, @@global.accountnum)
        rbox.upload_vol(:b, @option.bucket, :m, "/tmp/#{@option.name}.manifest.xml", :a, @@global.accesskey, :s, @@global.secretkey)

        @rimages.register("#{@option.bucket}/#{@option.name}.manifest.xml")
        
        break
      end
      
    end
    
    def destroy_images_valid?
      unless @argv.ami && Rudy::Utils.is_id?(:image, @argv.ami)  
        raise "Must supply an AMI ID (ami-XXXXXXX)" 
      end
      @rimages = Rudy::AWS::EC2::Images.new(@@global.accesskey, @@global.secretkey, @@global.region)
    end
    def destroy_images
     puts @rimages.deregister(@argv.ami) ? "Done" : "Unknown error"
    end 
    
    def register_images_valid?
      unless @argv.first
        raise "Must supply a valid manifest path (bucket/ami-name.manifest.xml)"
      end
      @rimages = Rudy::AWS::EC2::Images.new(@@global.accesskey, @@global.secretkey, @@global.region)
    end
    def register_images
      puts @rimages.register(@argv.first)
    end


  end


end; end
end; end


