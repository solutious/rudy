

require 'EC2'
require 'aws_sdb'


module Rudy
  module AWS
    extend self
    
    @@ec2 = @@sdb = @@s3 = nil
    
    def ec2; @@ec2; end
    def sdb; @@sdb; end
    def  s3; @@s3;  end
    
    
    def self.connect(akey, skey)
      @@ec2 ||= Rudy::AWS::EC2.new(akey, skey)
      @@sdb ||= Rudy::AWS::SimpleDB.new(akey, skey)
      #@@s3 ||= Rudy::AWS::S3.new(akey, skey)
    end
      
    def self.reconnect(akey, skey)
      # TODO: Synchronize!
      @@ec2 = Rudy::AWS::EC2.new(akey, skey)
      @@sdb = Rudy::AWS::SimpleDB.new(akey, skey)
      #@@s3 ||= Rudy::AWS::S3.new(akey, skey)
    end
    
    # Modifies +str+ by removing <tt>[\0\n\r\032\\\\]</tt> and escaping <tt>[\'\"]</tt>
    def escape(str)
      str.to_s.tr("[\0\n\r\032\\\\]", '').gsub(/([\'\"])/, '\\1\\1')
    end
    def escape!(str)
      str.to_s.tr!("[\0\n\r\032\\\\]", '').gsub!(/([\'\"])/, '\\1\\1')
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
        timeout ||= 30
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
        rescue SocketError => ex
          STDERR.puts "Socket Error. Check your Internets!"
        ensure
          response ||= default
        end
        response
      end
    end
    
    require 'rudy/aws/simpledb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
    
    # Require EC2, S3, Simple DB classes
    begin
      # TODO: Use autoload
      Dir.glob(File.join(RUDY_LIB, 'rudy', 'aws', '{ec2,s3,sdb}', "*.rb")).each do |path|
        require path
      end
    rescue LoadError => ex
      puts "Error: #{ex.message}"
      exit 1
    end
    
  end
  
end

