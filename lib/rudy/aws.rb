

require 'ec2'


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
        ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
        @instances = Rudy::AWS::EC2::Instances.new(ec2)
        @images = Rudy::AWS::EC2::Images.new(ec2)
        @groups = Rudy::AWS::EC2::Groups.new(ec2)
        @addresses = Rudy::AWS::EC2::Addresses.new(ec2)
        @snapshots = Rudy::AWS::EC2::Snapshots.new(ec2)
        @volumes = Rudy::AWS::EC2::Volumes.new(ec2)
      end
    
    end
  
    class S3
      @@logger = StringIO.new

      attr_reader :aws

      def initialize(access_key, secret_key)
       # @aws = RightAws::S3.new(access_key, secret_key, {:logger => Logger.new(@@logger)})
      end
    end
    
    class SimpleDB
      @@logger = StringIO.new
    
      attr_reader :domains
      attr_reader :aws
    
      def initialize(access_key, secret_key)
        #@aws = RightAws::SdbInterface.new(access_key, secret_key, {:logger => Logger.new(@@logger)})
        @aws = AwsSdb::Service.new(:access_key_id => access_key, :secret_access_key => secret_key, :logger => Logger.new(@@logger))
        @domains = Rudy::AWS::SimpleDB::Domains.new(@aws)
      end

    end
    
    require 'rudy/aws/simpledb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
  end
  
end

# Require EC2, S3, Simple DB class
begin
  # TODO: Use autoload
  Dir.glob(File.join(RUDY_LIB, 'rudy', 'aws', '{ec2,s3,sdb}', "*.rb")).each do |path|
    require path
  end
rescue LoadError => ex
  puts "Error: #{ex.message}"
  exit 1
end

