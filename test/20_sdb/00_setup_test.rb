require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  # Expects:
  # * There to be no pre-existing keypairs, addresses, etc... (except 
  #   the default group)
  # * It can destroy instances, images, etc... 
  #
  # DO NOT RUN THIS TEST ON A PRODUCTION AWS ACCOUNT!!
  #
  class Case_20_SimpleDB < Test::Unit::TestCase
    include Rudy::AWS
    
    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Instances.new(:logger => @@logger)
    @@global = @@rmach.global
    @@config = @@rmach.config
    @@zone = @@rmach.global.zone.to_s
    
    context "#{name}_00 Setup" do
      should "(00) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Instances), "We don't have an instance ofRudy::Instancess (#{@@rmach})"
        stop_test !@@sdb.is_a?(Rudy::AWS::SimpleDB), "We don't have an instance of Rudy::AWS::EC2 (#{@@ec2})"
      end
      should "(01) be zone" do
        stop_test !@@zone, "No zone"
      end
    end
  end
  
end