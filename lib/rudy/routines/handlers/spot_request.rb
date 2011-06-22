module Rudy; module Routines; module Handlers;
  module SpotRequest
    include Rudy::Routines::Handlers::Base
    extend self

    def needed?
      current_machine_pricing.is_a?(Hash) || current_machine_pricing.to_sym == :spot
    end

    def create
      opts = {
        :price => current_machine_pricing[:bid],
        :count => current_machine_positions.length,
        :size => current_machine_size,
        :os => current_machine_os,
        :ami => current_machine_image,
        :group => current_group_name,
        :keypair => root_keypairname
      }

      request = Rudy::AWS::EC2::SpotRequests.create(opts)
      raise NoMachines unless wait_for_fulfillment_of(request)
      Rudy::AWS::EC2::SpotRequests.list(request)
    rescue NoMachines
      Rudy::AWS::EC2::SpotRequests.cancel(request)
      raise SpotRequestCancelled
    end

    def wait_for_fulfillment_of(spot_requests)
      msg = "Waiting for #{spot_requests.length} spot requests to be fulfilled"
      Rudy::Utils.waiter(2, 180, Rudy::Huxtable.logger, msg, 2) {
        Rudy::AWS::EC2::SpotRequests.fulfilled?(spot_requests)
      }
    end

  end
end; end; end