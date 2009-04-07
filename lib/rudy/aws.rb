

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
      
      
    protected

      # Execute AWS requests safely. This will trap errors and return
      # a default value (if specified).
      # * +default+ A default response value
      # * +request+ A block which contains the AWS request
      # Returns the return value from the request is returned untouched
      # or the default value on error or if the request returned nil. 
      def execute_request(default=nil, timeout=nil, &request)
        timeout ||= 10
        raise "No block provided" unless request
        response = nil
        begin
          Timeout::timeout(timeout) do
            response = request.call
          end
        rescue ::EC2::Error => ex
          STDERR.puts ex.message
        rescue ::EC2::InvalidInstanceIDMalformed => ex
          STDERR.puts ex.message
        rescue Timeout::Error => ex
          STDERR.puts "Timeout (#{timeout}): #{ex.message}!"
          false
        ensure
          response ||= default
        end
        response
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

