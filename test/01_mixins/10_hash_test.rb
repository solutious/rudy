require File.join(File.dirname(__FILE__), '..', 'helper')

module Rudy::Test

  class Case_01_Mixins < Test::Unit::TestCase
    
    def one_level; {:empty=>1}; end
    def two_levels; {:l1 => {:empty=>1}}; end
    def three_levels; { :l1 => { :l2 => {:empty=>1, :empty=>1} } }; end
    def six_levels; {:l1 => {:l2 => {:l3 => {:l4 => {:l5 => {}, :empty=>1}, :empty=>1}}}}; end
     
    context "#{name}_10 Hash" do
      
      should "(10) should calculate deepest point" do
        assert_equal one_level.deepest_point, 1
        assert_equal two_levels.deepest_point, 2
        assert_equal three_levels.deepest_point, 3
        assert_equal six_levels.deepest_point, 6
      end
      
    end
    
  end
  
end