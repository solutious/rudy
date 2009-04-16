

require 'EC2'
require 'aws_sdb'


module Rudy
  module AWS
    extend self
    
    unless defined?(Rudy::AWS::VALID_REGIONS)
      VALID_REGIONS = ['eu-west-1', 'us-east-1'].freeze
    end
    
    def valid_region?(r); VALID_REGIONS.member?(r.to_s || ''); end
    
    # Modifies +str+ by removing <tt>[\0\n\r\032\\\\]</tt> and escaping <tt>[\'\"]</tt>
    def escape(str)
      str.to_s.tr("[\0\n\r\032\\\\]", '').gsub(/([\'\"])/, '\\1\\1')
    end
    def escape!(str)
      str.to_s.tr!("[\0\n\r\032\\\\]", '').gsub!(/([\'\"])/, '\\1\\1')
    end
    
    module ObjectBase
      
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
        # Raise the EC2 exceptions
        rescue ::EC2::Error, ::EC2::InvalidInstanceIDMalformed => ex  
          raise Rudy::AWS::Error, ex.message
        
        # NOTE: The InternalError is returned for non-existent volume IDs. 
        # It's probably a bug so we're ignoring it -- Dave. 
        rescue ::EC2::InternalError => ex
          raise Rudy::AWS::Error, ex.message
          
        rescue Timeout::Error => ex
          STDERR.puts "Timeout (#{timeout}): #{ex.message}!"
        rescue SocketError => ex
          STDERR.puts "Socket Error. Check your Internets!"
          STDERR.puts ex.message
          STDERR.puts ex.backtrace
        ensure
          response ||= default
        end
        response
      end
    end
    
    require 'rudy/aws/sdb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
    Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'aws', '{ec2,s3,sdb}', "*.rb")
    
    class Error < ::EC2::Error; end
  end
  
end

