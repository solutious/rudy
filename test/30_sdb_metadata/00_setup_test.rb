require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test
  class Case_30_MetaData < Test::Unit::TestCase
    include Rudy::AWS
    
    @@logger = StringIO.new
    @@rmach = Rudy::Instances.new(:logger => @@logger)
    @@global = @@rmach.global
    @@config = @@rmach.config
    @@zone = @@rmach.global.zone.to_s
    

    
    context "#{name}_00 Setup" do
      should "(00) have class variables setup" do
        stop_test !@@rmach.is_a?(Rudy::Instances), "We don't have an instance ofRudy::Instancess (#{@@rmach})"
        stop_test !@@global.is_a?(OpenStruct), "We don't have global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
      end
    end
    
    at_exit {
      @@logger.rewind
      puts @@logger.read
    }
  end
end