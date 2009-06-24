
group "Mixins"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Hash" do
  setup do
    def one_lvl; {:empty=>1}; end
    def two_lvls; {:l1 => {:empty=>1}}; end
    def three_lvls; { :l1 => { :l2 => {:empty=>1, :empty=>1} } }; end
    def six_lvls; {:l1 => {:l2 => {:l3 => {:l4 => {:l5 => {}, :empty=>1}, :empty=>1}}}}; end
  end
  
  dream [1, 2, 3, 6]
  drill "should calculate deepest point" do
    [one_lvl.deepest_point, two_lvls.deepest_point, 
     three_lvls.deepest_point, six_lvls.deepest_point]
  end
end


