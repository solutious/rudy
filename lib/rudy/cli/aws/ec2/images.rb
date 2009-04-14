

module Rudy; module CLI; 
module AWS; module EC2;
  
  class Images < Rudy::CLI::Base

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
   #def create_images
   #  puts "Creating image from #{machine_group}"
   #  
   #  # ~/.rudy, /etc/motd, history -c, /etc/hosts, /var/log/rudy*
   #  
   #  execute_check(:medium)
   #  
   #  
   #  machine_list = @ec2.instances.list(machine_group)
   #  machine = machine_list.values.first  # NOTE: Only one machine per group, for now...
   #
   #  raise "There's no machine running in #{machine_group}" unless machine
   #  raise "The primary machine in #{machine_group} is not in a running state" unless machine[:aws_state] == 'running'
   #  
   #  puts "The new image will be based on #{machine_group}_01"
   #  
   #  @option.account ||= @config.accounts.aws.accountnum
   #  
   #  # TODO: Don't reset global here
   #  unless @option.account
   #    puts "Enter your 12 digit Amazon account number:"
   #    @global.accountnum = gets.chomp
   #  end
   #  
   #  unless @option.image_name
   #    puts "Enter the image name:"
   #    @option.image_name = gets.chomp
   #  end
   #  
   #  unless @option.bucket_name
   #    puts "Enter the S3 bucket that will store the image:"
   #    @option.bucket_name = gets.chomp
   #  end
   #  
   #  unless @option.print
   #    puts "Copying .pem keys to /mnt (they will not be included in the AMI)"
   #    scp_command machine[:dns_name], keypairpath, @global.user, @global.cert, "/mnt/"
   #    scp_command machine[:dns_name], keypairpath, @global.user, @global.privatekey, "/mnt/"
   #  end
   #  
   #  ssh do |session|
   #    session.exec!("touch /root/firstrun")
   #  end
   #  
   #  puts "Starting bundling process...".bright
   #  puts ssh_command(machine[:dns_name], keypairpath, @global.user, "ec2-bundle-vol -r i386 -p #{@option.image_name} -k /mnt/pk-*pem -c /mnt/cert*pem -u #{@option.account}", @option.print)
   #  puts ssh_command(machine[:dns_name], keypairpath, @global.user, "ec2-upload-bundle -b #{@option.bucket_name} -m /tmp/#{@option.image_name}.manifest.xml -a #{@global.accesskey} -s #{@global.secretkey}", @option.print)
   #
   #  @ec2.images.register("#{@option.bucket_name}/#{@option.image_name}.manifest.xml") unless @option.print
   #end
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
    
    
    def images_valid?
      if @option.owner == 'self'
        raise "AWS_ACCOUNT_NUMBER not set" unless @@global.accountnum 
        @option.owner = @@global.accountnum 
      end
      
      true  
    end
    def images
      
      @option.owner ||= 'amazon'
      puts "Images owned by #{@option.owner.bright}" unless @argv.awsid
      rimages = Rudy::AWS::EC2::Images.new(@@global.accesskey, @@global.secretkey)
      images = rimages.list(@option.owner, @argv) || []
      images.each do |img|
        puts @@global.verbose > 0 ? img.inspect : img.dump(@@global.format)
      end
      puts "No images"
    end

    
    end


end; end
end; end


