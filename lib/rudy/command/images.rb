

module Rudy
  module Command
    class Images < Rudy::Command::Base
      

      def images
        @ec2.images.list.each do |img|
          print_image img
        end
      end
      
      def create_images_valid?
        puts "Make sure the machine is clean. I don't want archive no crud!"
        exit unless are_you_sure?
        true
      end
      
      
      def prepare_images
        # TODO: Avail hooks for clean an instance
        # Clean off Rudy specific crap. 
      end
      
      
      def create_images
        
        switch_user("root")
        
        puts "TODO: clean transient rudy crap off of instance before making image!!!"
        # ~/.rudy, /etc/motd, history -c, /etc/hosts, /var/log/rudy*
        exit
        
        raise "No EC2 .pem keys provided" unless has_pem_keys?
        raise "No SSH key provided for #{keypairname}!" unless has_keypair?(keypairname)
        raise "SSH key provided but cannot be found! (#{keypairpath})" unless File.exists?(keypairpath)
        
        machine_list = @ec2.instances.list(machine_group)
        machine = machine_list.values.first  # NOTE: Only one machine per group, for now...

        raise "There's no machine running in #{machine_group}" unless machine
        raise "The primary machine in #{machine_group} is not in a running state" unless machine[:aws_state] == 'running'
        
        puts "The new image will be based on #{machine_group}_01"
        
        @option.account ||= @global.account_num
        
        unless @global.account
          puts "Enter your 12 digit Amazon account number:"
          @global.account = gets.chomp
        end
        
        unless @option.image_name
          puts "Enter the image name:"
          @option.image_name = gets.chomp
        end
        
        unless @option.bucket_name
          puts "Enter the S3 bucket that will store the image:"
          @option.bucket_name = gets.chomp
        end
        
        scp_command machine[:dns_name], keypairpath, @global.user, @global.cert, "/mnt/"
        scp_command machine[:dns_name], keypairpath, @global.user, @global.privatekey, "/mnt/"
        
        ssh_command machine[:dns_name], keypairpath, @global.user, "ec2-bundle-vol -r i386 -p #{@option.image_name} -k /mnt/pk-*pem -c /mnt/cert*pem -u #{@option.account}"
        ssh_command machine[:dns_name], keypairpath, @global.user, "ec2-upload-bundle -b #{@option.bucket_name} -m /tmp/#{@option.image_name}.manifest.xml -a #{@global.accesskey} -s #{@global.secretkey}"
        
        @ec2.images.register("#{@option.bucket_name}/#{@option.image_name}.manifest.xml")
      end
      
      def deregister
        ami = @argv.first
        raise "You must supply an AMI ID (ami-XXXXXXX)" unless ami
        puts "Deregistering AMI: #{ami}"
        
        are_you_sure?
        
        if @ec2.images.deregister(ami)
          puts "Done!"
        else
          puts "There was an unknown problem!"
        end
        
      end
      
    end
  end
end

