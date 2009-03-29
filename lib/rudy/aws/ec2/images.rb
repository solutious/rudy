

module Rudy::AWS
  class EC2
    
    class Images
      include Rudy::AWS::ObjectBase
      
      # Returns an array of hashes:
      # {:aws_architecture=>"i386", :aws_owner=>"105148267242", :aws_id=>"ami-6fe40dd5", 
      #  :aws_image_type=>"machine", :aws_location=>"bucket-name/your-image.manifest.xml", 
      #  :aws_kernel_id=>"aki-a71cf9ce", :aws_state=>"available", :aws_ramdisk_id=>"ari-a51cf9cc", 
      #  :aws_is_public=>false}
      def list
        @aws.describe_images_by_owner('self') || []
      end
      
      # +id+ AMI ID to deregister (ami-XXXXXXX)
      # Returns true when successful. Otherwise throws an exception.
      def deregister(id)
        @aws.deregister_image(id)
      end
      
      # +path+ the S3 path to the manifest (bucket/file.manifest.xml)
      # Returns the AMI ID when successful, otherwise throws an exception.
      def register(path)
        @aws.register_image(path)
      end
    end
    
    
  end
end