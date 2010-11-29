

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
      unless @option.all
        @option.owner ||= 'amazon' 
        li "Images owned by #{@option.owner.bright}" unless @argv.awsid
      end
      images = Rudy::AWS::EC2::Images.list(@option.owner, @argv) || []
      print_stobjects images
    end
    
    def destroy_images_valid?
      unless @argv.ami && Rudy::Utils.is_id?(:image, @argv.ami)  
        raise "Must supply an AMI ID (ami-XXXXXXX)" 
      end
      true
    end
    def destroy_images
     li Rudy::AWS::EC2::Images.deregister(@argv.ami) ? "Done" : "Unknown error"
    end 
    
    def register_images_valid?
      unless @argv.first
        raise "Must supply a valid manifest path (bucket/ami-name.manifest.xml)"
      end
      true
    end
    def register_images
      if @option.snapshot
        opts = {
          :name => @argv.first,
          :architecture => @option.arch || 'i386',
          :description => @option.description || 'Made with Rudy',
          :root_device_name => "/dev/sda1",
          :block_device_mapping => [{
            :device_name => "/dev/sda1",
            :ebs_snapshot_id => @option.snapshot,
            :ebs_delete_on_termination => true
          }]
        }
        opts[:kernel_id] = @option.kernel if @option.kernel
        opts[:ramdisk_id] = @option.ramdisk if @option.ramdisk
      else
        opts = {
          :image_location => @argv.first
        }
      end
      p opts if Rudy.debug?
      li Rudy::AWS::EC2::Images.register(opts)
    end


  end


end; end
end; end


