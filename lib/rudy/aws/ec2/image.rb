

module Rudy::AWS
  class EC2::Image < Storable
    @@sformat = "   -> %8s; %12s; %12s; %12s; %8s"
    
    field :awsid => String
    field :owner => String
    field :aki => String
    field :ari => String
    field :state => String
    field :arch => String
    field :visibility => String
    field :location => String
    field :kind => String
        
    def to_s(with_title=false)
      [@awsid.bright, @arch, @visibility, @location].join '; '
    end
    
    def available?; @state && @state == "available"; end
    def public?; @visibility && @visibility == 'public'; end
    def private?; !public? end
    
  end
  
  module EC2    
    module Images
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend

      
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
        
        response = Rudy::AWS::EC2.execute_request({}) { @@ec2.describe_images(opts) }
        
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
        ret = @@ec2.deregister_image(opts)
        return false unless ret && ret.is_a?(Hash)
        true
      end
      
      # +opts+ can be the S3 path to the manifest (bucket/file.manifest.xml)
      # or a hash containing the following options:
      #
      # [optional, String] :image_location ("") S3 URL for the XML manifest
      # [optional, String] :name ("") Name of EBS image
      # [optional, String] :description ("") Description of EBS image
      # [optional, String] :architecture ("") Architecture of EBS image, currently 'i386' or 'x86_64'
      # [optional, String] :kernel_id ("") Kernel ID of EBS image
      # [optional, String] :ramdisk_id ("") Ramdisk ID of EBS image
      # [optional, String] :root_device_name ("") Root device name of EBS image, eg '/dev/sda1'
      # [optional, Array] :block_device_mapping ([]) An array of Hashes representing the elements of the block device mapping.  e.g. [{:device_name => '/dev/sdh', :virtual_name => '', :ebs_snapshot_id => '', :ebs_volume_size => '', :ebs_delete_on_termination => ''},{},...]
      #                       i.e. 
      #                        :block_device_mapping => [{
      #                          :device_name => "/dev/sda1",
      #                          :ebs_snapshot_id => "snap-01234567",
      #                          :ebs_delete_on_termination => true,
      #                        }]
      def register(opts)
        opts = Hash === opts ? opts : { :image_location => opts }
        ret = @@ec2.register_image(opts)
        return nil unless ret && ret.is_a?(Hash)
        ret['imageId']
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
          if !img.is_a?(Rudy::AWS::EC2::Image) && !Rudy::Utils.is_id?(:image, img)
            raise %Q("#{img}" is not an image ID or object)
          end
          img.is_a?(Rudy::AWS::EC2::Image) ? img.awsid : img
        end
        img_ids
      end
      
    end

  end
end