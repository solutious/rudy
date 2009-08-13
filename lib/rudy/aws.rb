

require 'AWS'       # amazon-ec2 gem


module Rudy
  module AWS
    extend self
    
    unless defined?(Rudy::AWS::VALID_REGIONS)
      VALID_REGIONS = [:'eu-west-1', :'us-east-1'].freeze
    end
    
    def valid_region?(r); VALID_REGIONS.member?(r.to_sym || ''); end
    
    # Modifies +str+ by removing <tt>[\0\n\r\032\\\\]</tt> and escaping <tt>[\'\"]</tt>
    def escape(str)
      str.to_s.tr("[\0\n\r\032\\\\]", '').gsub(/([\'\"])/, '\\1\\1')
    end
    def escape!(str)
      str.to_s.tr!("[\0\n\r\032\\\\]", '').gsub!(/([\'\"])/, '\\1\\1')
    end
        
    require 'rudy/aws/sdb'
    require 'rudy/aws/ec2'
    require 'rudy/aws/s3'
    
    Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'aws', '{ec2,s3,sdb}', "*.rb")
    
    class Error < ::AWS::Error; end
  end
  
end

