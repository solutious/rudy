

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

    
    def create_images_valid?
      raise "No account number" unless @@global.accountnum 
      true
    end
    
    def create_images
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all
      opts[:id] = @option.instid if @option.instid
      
      # Options to be sent to Net::SSH
      ssh_opts = { :user => @option.user || Rudy.sysinfo.user, :debug => nil  }
      if @option.pkey 
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise InsecureKeyPermissions, @option.pkey unless File.stat(@option.pkey).mode == 33152
        ssh_opts[:keys] = @option.pkey 
      end
      
      unless @option.name
        puts "Enter the image name:"
        @option.image_name = gets.chomp
      end

      unless @option.bucket
        puts "Enter the S3 bucket that will store the image:"
        @option.bucket_name = gets.chomp
      end
      
      #execute_check(:medium)
      
      checked = false
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        puts inst.dns_public
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
        
        # ~/.rudy, /etc/motd, history -c, /etc/hosts, /var/log/rudy*
        
        #puts "Copying .pem keys to /mnt (they will not be included in the AMI)"
        #scp_command machine[:dns_name], keypairpath, @global.user, @global.cert, "/mnt/"
        #scp_command machine[:dns_name], keypairpath, @global.user, @global.privatekey, "/mnt/"
        #
        #session.exec!("touch /root/firstrun")
        #
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


