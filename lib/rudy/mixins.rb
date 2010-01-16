

module REXML
  module Node
    include Gibbler::String
  end
end

class Hash
  # A depth-first look to find the deepest point in the Hash. 
  # The top level Hash is counted in the total so the final
  # number is the depth of its children + 1. An example:
  # 
  #     ahash = { :level1 => { :level2 => {} } }
  #     ahash.deepest_point  # => 3
  #
  def deepest_point(h=self, steps=0)
    if h.is_a?(Hash)
      steps += 1
      h.each_pair do |n,possible_h|
        ret = deepest_point(possible_h, steps)
        steps = ret if steps < ret
      end
    else
      return 0
    end
    steps
  end  
end

class Symbol
  unless method_defined? :empty?
    def empty?
      self.to_s.empty?
    end
  end
end
