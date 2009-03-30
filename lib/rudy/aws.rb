

require 'ec2'
require 'aws_sdb'

module Rudy
  module AWS
    extend self
    @@ec2 = @@sdb = @@s3 = nil
    
    
    def ec2; @@ec2; end
    def sdb; @@sdb; end
    def  s3; @@s3;  end
    
    def set_access_identifiers(accesskey, secretkey, logger=nil)
      @@ec2 ||= Rudy::AWS::EC2.new(accesskey, secretkey)
      @@sdb ||= Rudy::AWS::SimpleDB.new(accesskey, secretkey)
      #@@s3 ||= Rudy::AWS::SimpleDB.new(accesskey, secretkey)
    end
      
    module ObjectBase
      attr_accessor :aws
      def initialize(aws_connection)
        @aws = aws_connection
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

