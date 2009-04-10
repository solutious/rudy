require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test

  class Case_05_Config < Test::Unit::TestCase

    @@logger = STDERR #StringIO.new
    @@rmach = Rudy::Machines.new
    @@global = @@rmach.global
    @@config = @@rmach.config
    @@zone = @@rmach.global.zone.to_s
    
    context "#{name}_00 Setup" do
      should "(00) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Machines), "We don't have an instance ofRudy::Machiness (#{@@rmach})"
        stop_test !@@global.is_a?(OpenStruct), "We don't have global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
      end
    end
    
    
  end
end