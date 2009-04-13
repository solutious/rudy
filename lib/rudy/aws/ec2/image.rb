

module Rudy::AWS
  module EC2
    
    class Images
      include Rudy::AWS::ObjectBase
      
      
      def list()
        opts = {
          :image_id => [],
          :owner_id => [],
          :executable_by => []
        }
        ret = @aws.describe_images_by_owner(opts) || []
        puts ret.to_yaml
        []
      end
      
      # +id+ AMI ID to deregister (ami-XXXXXXX)
      # Returns true when successful. Otherwise throws an exception.
      def deregister(id)
        opts = {
          :image_id => id
        }
        ret = @aws.deregister_image(opts)
        puts ret.to_yaml
        true
      end
      
      # +path+ the S3 path to the manifest (bucket/file.manifest.xml)
      # Returns the AMI ID when successful, otherwise throws an exception.
      def register(path)
        opts = {
          :image_location => path
        }
        ret = @aws.register_image(opts)
        puts ret.to_yaml
        true
      end
    end
    
    
  end
end