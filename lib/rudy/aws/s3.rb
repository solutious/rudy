
module Rudy::AWS
  class S3
    
    def initialize(access_key=nil, secret_key=nil, region=nil, debug=nil)
      require 'aws/s3'    
      
      url ||= 'http://sdb.amazonaws.com'
      # There is a bug with passing :server to EC2::Base.new so 
      # we'll use the environment variable for now. 
      #if region && Rudy::AWS.valid_region?(region)
      #  "#{region}.sdb.amazonaws.com"
      #end
      
      @access_key_id = access_key || ENV['AWS_ACCESS_KEY'] || ENV['AMAZON_ACCESS_KEY_ID']
      @secret_access_key = secret_key || ENV['AWS_SECRET_KEY'] || ENV['AMAZON_SECRET_ACCESS_KEY']
      @base_url = url
      @debug = debug || StringIO.new
      
      
      AWS::S3::Base.establish_connection!(
        :access_key_id     => @access_key_id,
        :secret_access_key => @secret_access_key
      )
      
    end
    
    def list_buckets
      ::AWS::S3::Service.buckets
    end
    
    def create_bucket(name, location=nil)
      opts = {}
      opts[:location] = location.to_s.upcase if location
      ::AWS::S3::Bucket.create(name, opts)
    end
    
    def destroy_bucket(name)
      ::AWS::S3::Bucket.delete(name)
    end
    
    def find_bucket(name)
      blist = ::AWS::S3::Service.buckets
      blist.select { |bobj| bobj.name == name }.first
    end
    
    def list_bucket_objects(name)
      ::AWS::S3::Bucket.objects(name)
    end
    
    #def store(path, bucket)
    #  fname = File.basename(path)
    #  S3Object.store(fname, open(path), bucket)
    #end
    
    def bucket_exists?(name)
      b = find_bucket(name)
      !b.nil?
    end
    
    autoload :Error, 'rudy/aws/sdb/error'
    
  end
end