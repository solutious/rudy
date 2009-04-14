require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class Case_26_EC2 < Test::Unit::TestCase
    include Rudy::Huxtable
    
    @@logger = STDERR #StringIO.new
    @@zone = @@global.zone.to_s
    
    context "#{name}_10 Setup" do
      should "(10) have class variables setup" do
        stop_test !@@global.is_a?(Rudy::Global), "We don't have Rudy::Global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
      end
      should "(11) be zone" do
        stop_test !@@zone, "No zone"
      end
    end
  end
  
end