

module Rudy::AWS
  class EC2::Image < Storable
    @@sformat = "   -> %8s; %12s; %12s; %12s; %8s"
    
    field :awsid
    field :owner
    field :aki
    field :ari
    field :state
    field :arch
    field :visibility
    field :location
    field :kind
    
    def liner_note
      info = @location
      # Highlight "debian-5" in /dir/debian-5.manifest.xml
      #info = info.split(/\//) 
      #info[-1].gsub!(/(.+?)((\.img)?\.manifest\.xml)/) { |m,n| ($1 || "").bright << $2 }
      #info = info.join('/')
      "%s (%s)" % [self.awsid.bright, info] 
    end
        
    def to_s(with_title=false)
      lines = []
      lines << liner_note
      if self.available?
        p = public? ? "public" : "private" 
        k, r = @aki || 'aki-unknown', @ari || 'ari-unknown'
        lines << @@sformat % %w{arch owner aki ari visibility} if with_title
        lines << @@sformat % [@arch, @owner, k, r, p]
      end
      lines.join($/)
    end
    
    def inspect
      lines = []
      lines << liner_note
      field_names.each do |key|
        next unless self.respond_to?(key)
        val = self.send(key)
        lines << sprintf(" %22s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      lines.join($/)
    end
    
    def available?; @state && @state == "available"; end
    def public?; @visibility && @visibility == 'public'; end
    def private?; !public? end
    
  end
  
  module EC2
    
    class Images
      include Rudy::AWS::ObjectBase
      include Rudy::AWS::EC2::Base
      
      def list(owner=[], image_ids=[], executable_by=[], &each_image)
        images = list_as_hash(owner, image_ids, executable_by)
        images &&= images.values
        images
      end
      
      def list_as_hash(owner=[], image_ids=[], executable_by=[], &each_image)
        owner &&= [owner].flatten.compact
        image_ids &&= [image_ids].flatten.compact
        executable_by &&= [executable_by].flatten.compact
        
        # Remove dashes from aws account numbers
        owner &&= owner.collect { |o| o.tr('-', '') }
        # If we got Image objects, we want just the IDs.
        # This method always returns an Array.
        image_ids = objects_to_image_ids(image_ids)
        
        opts = {
          :owner_id => owner || [],
          :image_id => image_ids || [],
          :executable_by => executable_by || []
        }
        
        response = execute_request({}) { @ec2.describe_images(opts) }
        
        return nil unless response['imagesSet'].is_a?(Hash)  # No instances 
      
        resids = []
        images = {}
        response['imagesSet']['item'].each do |res|      
          resids << res['reservationId']
          img = Images.from_hash(res)
          images[img.awsid] = img
        end
        
        images.each_value { |image| each_image.call(image) } if each_image
        
        images = nil if images.empty? # Don't return an empty hash
        images
      end
      
      # +id+ AMI ID to deregister (ami-XXXXXXX)
      # Returns true when successful. Otherwise throws an exception.
      def deregister(id)
        opts = {
          :image_id => id
        }
        ret = @ec2.deregister_image(opts)
        puts ret.to_yaml
        true
      end
      
      # +path+ the S3 path to the manifest (bucket/file.manifest.xml)
      # Returns the AMI ID when successful, otherwise throws an exception.
      def register(path)
        opts = {
          :image_location => path
        }
        ret = @ec2.register_image(opts)
        puts ret.to_yaml
        true
      end
      
      #     imageOwnerId: "203338247012"
      #     kernelId: aki-a71cf9ce
      #     ramdiskId: ari-a51cf9cc
      #     imageState: available
      #     imageId: ami-dd34d3b4
      #     architecture: i386
      #     isPublic: "false"
      #     imageLocation: solutious-rudy-us/debian-squeeze-m1.small-v5.manifest.xml
      #     imageType: machine
      def Images.from_hash(h)
        img = Rudy::AWS::EC2::Image.new
        img.owner = h['imageOwnerId']
        img.aki = h['kernelId']
        img.ari = h['ramdiskId']
        img.state = h['imageState']
        img.awsid = h['imageId']
        img.arch = h['architecture']
        img.visibility = h['isPublic'] == 'true' ? 'public' : 'private'
        img.location = h['imageLocation']
        img.kind = h['imageType']
        img
      end
      
      
    private
    
      # * +img_ids+ an Array of images IDs (Strings) or Image objects.
      # Note: This method removes nil values and always returns an Array.
      # Returns an Array of image IDs. 
      def objects_to_image_ids(img_ids)
        img_ids = [img_ids].flatten    # Make sure it's an Array
        img_ids = img_ids.collect do |img|
          next if img.nil? || img.to_s.empty?
          if !img.is_a?(Rudy::AWS::EC2::Image) && !Rudy.is_id?(:image, img)
            raise %Q("#{img}" is not an image ID or object)
          end
          img.is_a?(Rudy::AWS::EC2::Image) ? img.awsid : img
        end
        img_ids
      end
      
    end

  end
end