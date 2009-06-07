require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class Case_25_EC2 < Test::Unit::TestCase
    include Rudy::Huxtable
    
    @@zone = @@global.zone.to_s

    
    context "#{name}_00 Setup" do
      should "(10) have class variables setup" do
        stop_test !@@global.is_a?(Rudy::Global), "We don't have global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
        stop_test !@@global.accountnum, "No account number"
      end
      should "(11) be zone" do
        stop_test !@@zone, "No zone"
      end
    end
  end
  
end