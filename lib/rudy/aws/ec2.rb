
module Rudy; module AWS
  module EC2
    module Base
      def initialize(access_key, secret_key)
        @ec2 = ::EC2::Base.new(:access_key_id => access_key, :secret_access_key => secret_key)
      end
    end
  end
end; end