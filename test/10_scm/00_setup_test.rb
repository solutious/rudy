require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test

  class Case_10_SCM < Test::Unit::TestCase
    include Rudy::Huxtable
    
    @@logger = STDERR #StringIO.new
    @@zone = @@global.zone.to_s
    
    context "#{name}_00 Setup" do
      should "(00) have class variables setup" do
        stop_test !@@global.is_a?(Rudy::Global), "We don't have global (#{@@global})"
        stop_test !@@config.is_a?(Rudy::Config), "We don't have an instance of Rudy::Config (#{@@config})"
      end
    end
    
    
  end
end