require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class EC2 < Test::Unit::TestCase
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new(:logger => @@logger)
    @@ec2 = @@rmach.ec2
    @@zone = @@rmach.global.zone
    
    context "(00) Setup" do
      should "(10) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Machines), "We don't have an instance of Rudy::Machines (#{@@rmach})"
        stop_test !@@ec2.is_a?(Rudy::AWS::EC2), "We don't have an instance of Rudy::AWS::EC2 (#{@@ec2})"
        stop_test !@@rmach.config || !@@rmach.config.awsinfo || !@@rmach.config.awsinfo.account, "No account number"
      end
      should "(11) be zone" do
        stop_test !@@zone || @@zone.empty?, "No zone"
      end
    end
  end
  
end