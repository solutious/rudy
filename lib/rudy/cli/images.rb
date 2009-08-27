
module Rudy
  module CLI
    class Images < Rudy::CLI::CommandBase
      
      def bundle_valid?
        raise "No S3 bucket provided. See rudy bundle -h" unless @@global.bucket
        raise "No image name provided. See rudy bundle -h" unless @argv.name
          
        @machines = Rudy::Machines.list
        raise "No machines" if @machines.nil?
        
        @machines = @machines.select { |m| m.windows? }
        raise "No Windows machines" if @machines.nil?
        
        true
      end
      
      def bundle

        @machines.each do |m|
          li machine_separator(m.name, m.instid)

          cmd = "ec2-bundle-instance"
          args = [m.instid, "--region", @@global.region.to_s]
          args += ["-b", @@global.bucket, "-p", @argv.name]
          args += ["-o", @@global.accesskey, "-w", @@global.secretkey]
          args += ["-K", @@global.pkey, "-C", @@global.cert]
          
          # S3 returned 301 (Moved Permanently) for ACL on bucket [EU-BUCKET]
          args += ["--no-bucket-setup"] if @@global.region.to_s == 'eu-west-1'
          
          if @@global.verbose > 0
            li "Running: " << Rye.prepare_command(cmd, args), $/
          end
          
          unless @@global.quiet
            li "Bundling can take up to 60 minutes."
            li "Check the status with the following command:"
            li Rudy::Huxtable.generate_rudy_command('bundle-status').bright
            li $/, "When complete, register the image with the command:"
            li Rudy::Huxtable.generate_rudy_command('images', '-R', @argv.name).bright
          end
          
          execute_check(:medium)
          
          ret = Rye.shell cmd, args
          li ret.stderr, ret.stdout
        end
      end
      
      def bundle_status
        cmd = 'ec2-describe-bundle-tasks'
        args = ["--region", @@global.region.to_s]
        args += ["-K", @@global.pkey, "-C", @@global.cert]
        
        if @@global.verbose > 0
          li "Running: " << Rye.prepare_command(cmd, args), $/
        end
        
        ret = Rye.shell cmd, args
        li ret.stderr, ret.stdout
          
      end
      
      def register_images_valid?
        raise "No S3 bucket provided. See rudy bundle -h" unless @@global.bucket
        raise "No image name provided. See rudy bundle -h" unless @argv.name
        
        true
      end
      def register_images
        name = "#{@@global.bucket}/#{@argv.name}.manifest.xml"
        li Rudy::AWS::EC2::Images.register(name)
      end
      
      def deregister_images_valid?
        unless @argv.first && Rudy::Utils.is_id?(:image, @argv.first)  
          raise "Must supply an AMI ID. See rudy images -h" 
        end
        true
      end
      def deregister_images
        execute_check(:low)
        li Rudy::AWS::EC2::Images.deregister(@argv.ami) ? "Done" : "Unknown error"
      end
      
      def images
        @option.owner ||= 'self'
        images = Rudy::AWS::EC2::Images.list(@option.owner, @argv) || []
        print_stobjects images
      end
      
      
    end
  end
end