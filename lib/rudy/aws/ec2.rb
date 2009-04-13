
module Rudy; module AWS
  module EC2
    module Base
      def initialize(access_key, secret_key, logger=nil)
        @ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
        @logger = logger
      end
    end
  end
end; end