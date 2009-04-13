
module Rudy; module AWS
  module EC2
    module Base
      attr_accessor :ec2
      def initialize(access_key=nil, secret_key=nil, logger=nil)
        @ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
        @logger = logger
      end
    end
  end
end; end