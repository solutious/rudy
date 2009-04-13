

require 'EC2'
require 'aws_sdb'


module Rudy
  module AWS
    extend self
    
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
    
    require 'rudy/aws/sdb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
    Rudy.require_glob(RUDY_LIB, 'rudy', 'aws', '{ec2,s3,sdb}', "*.rb")
    
  end
  
end

