



module Rudy
  module AWS
        
    module ObjectBase
      attr_accessor :aws
      def initialize(aws_connection)
        @aws = aws_connection
      end
    end
  
    class EC2
      @@logger = StringIO.new

      attr_reader :instances
      attr_reader :images
      attr_reader :addresses
      attr_reader :groups
      attr_reader :volumes
      attr_reader :snapshots
      attr_reader :aws

      def initialize(access_key, secret_key)
        @aws = RightAws::Ec2.new(access_key, secret_key, {:logger => Logger.new(@@logger)})
        @instances = Rudy::AWS::EC2::Instances.new(@aws)
        @images = Rudy::AWS::EC2::Images.new(@aws)
        @groups = Rudy::AWS::EC2::Groups.new(@aws)
        @addresses = Rudy::AWS::EC2::Addresses.new(@aws)
        @snapshots = Rudy::AWS::EC2::Snapshots.new(@aws)
        @volumes = Rudy::AWS::EC2::Volumes.new(@aws)
      end
    
    end
  
    class S3
      @@logger = StringIO.new

      attr_reader :aws

      def initialize(access_key, secret_key)
        @aws = RightAws::S3.new(access_key, secret_key, {:logger => Logger.new(@@logger)})
      end
    end
    
    class SimpleDB
      @@logger = StringIO.new
    
      attr_reader :domains
      attr_reader :aws
    
      def initialize(access_key, secret_key)
        @aws = RightAws::SdbInterface.new(access_key, secret_key, {:logger => Logger.new(@@logger)})
        @aws2 = AwsSdb::Service.new(:access_key_id => access_key, :secret_access_key => secret_key, :logger => Logger.new(@@logger))
        @domains = Rudy::AWS::SimpleDB::Domains.new(@aws)
      end

    end
    
    require 'rudy/aws/simpledb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
  end
  
end
