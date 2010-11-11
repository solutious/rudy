

require 'AWS'       # amazon-ec2 gem


module Rudy
  module AWS
    extend self
    
    unless defined?(Rudy::AWS::VALID_REGIONS)
      VALID_REGIONS = [:'eu-west-1', :'us-east-1', :'us-west-1', :'ap-southeast-1'].freeze
    end
    
    def valid_region?(r); VALID_REGIONS.member?(r.to_sym || ''); end
    
    # Modifies +str+ by removing <tt>[\0\n\r\032\\\\]</tt> and escaping <tt>[\'\"]</tt>
    def escape(str)
      str.to_s.tr("[\0\n\r\032\\\\]", '').gsub(/([\'\"])/, '\\1\\1')
    end
    def escape!(str)
      str.to_s.tr!("[\0\n\r\032\\\\]", '').gsub!(/([\'\"])/, '\\1\\1')
    end
    
    autoload :SDB, 'rudy/aws/sdb'
    autoload :EC2, 'rudy/aws/ec2'
    autoload :S3, 'rudy/aws/s3'
    
    class Error < ::AWS::Error; end
  end
  
end

