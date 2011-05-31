
module Rudy::AWS
  module EC2

    class SpotRequest < Storable
      field :id => String
      field :price => Float
      field :type => String
      field :state => String
      field :ami => String
      field :keyname => String
      field :groups => Array
      field :size => String
      field :zone => String
      field :create_time => Time
      field :instid => String

      def fulfilled?
        instid && !instid.empty?
      end
    end


    module SpotRequests
      include Rudy::AWS::EC2  # important! include,
      extend self             # then extend

      # Return an Array of SpotRequest objects.
      #
      # +opts+ supports the following parameters:
      #
      # * +:price+
      # * +:count+
      # * +:zone+
      # * +:ami+
      # * +:group+
      # * +:size+
      # * +:keypair+
      # * +:private+ true or false (default)
      def create(opts)
        raise NoAMI unless opts[:ami]
        raise NoGroup unless opts[:group]

        opts = { :size => 'm1.small', :count => 1}.merge(opts)

        old_opts = {
          :spot_price => opts[:price].to_s,
          :instance_count => opts[:count].to_i,
          :availability_zone_group => (opts[:zone] || @@global.zone).to_s,
          :image_id => opts[:ami].to_s,
          :key_name => opts[:keypair].to_s,
          :security_group => opts[:group].to_s,
          :instance_type => opts[:size]
        }

        response = Rudy::AWS::EC2.execute_request({}) { @@ec2.request_spot_instances(old_opts) }
        self.from_request_set(response['spotInstanceRequestSet'])
      end

      def list(requests = nil)
        opts = requests ? {:spot_instance_request_id => requests.map(&:id)} : {}

        response = Rudy::AWS::EC2.execute_request({}) do
          @@ec2.describe_spot_instance_requests(opts)
        end

        self.from_request_set(response['spotInstanceRequestSet'])
      end

      def fulfilled?(requests)
        list(requests).all? { |r| r.fulfilled? }
      end

      def self.from_hash(hash)
        Rudy::AWS::EC2::SpotRequest.new.tap do |request|
          request.id = hash['spotInstanceRequestId']
          request.price = hash['spotPrice']
          request.type = hash['type']
          request.state = hash['state']
          request.ami = hash['launchSpecification']['imageId']
          request.keyname = hash['launchSpecification']['keyName']
          request.size = hash['launchSpecification']['instanceType']
          request.zone = hash['availabilityZoneGroup']
          request.create_time = hash['createTime']
          request.instid = hash['instanceId']

          request.groups = hash['launchSpecification']['groupSet']['item'].map do |item|
            item['groupId']
          end
        end
      end

      private

      def self.from_request_set(request_set)
        return unless request_set.is_a?(Hash)
        request_set['item'].collect do |request|
          self.from_hash(request)
        end
      end


    end

  end

end