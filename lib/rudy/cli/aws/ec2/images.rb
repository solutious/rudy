

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
        puts "Images owned by #{@option.owner.bright}" unless @argv.awsid
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
     puts Rudy::AWS::EC2::Images.deregister(@argv.ami) ? "Done" : "Unknown error"
    end 
    
    def register_images_valid?
      unless @argv.first
        raise "Must supply a valid manifest path (bucket/ami-name.manifest.xml)"
      end
      true
    end
    def register_images
      puts Rudy::AWS::EC2::Images.register(@argv.first)
    end


  end


end; end
end; end


