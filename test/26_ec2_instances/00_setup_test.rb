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
    
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new
    @@global = @@rmach.global
    @@config = @@rmach.config
    @@zone = @@rmach.global.zone.to_s
    @@ec2 = @@rmach.ec2
    
    context "#{name}_10 Setup" do
      should "(10) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Machines), "We don't have an instance ofRudy::Machiness (#{@@rmach})"
        stop_test !@@ec2.is_a?(Rudy::AWS::EC2), "We don't have an instance of Rudy::AWS::EC2 (#{@@ec2})"
        stop_test !@@global.is_a?(Rudy::Global), "We don't have global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
      end
      should "(11) be zone" do
        stop_test !@@zone, "No zone"
      end
    end
  end
  
end