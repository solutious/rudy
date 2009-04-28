

module Rudy
  module Guidelines #:nodoc:all
    extend self
    AFE = "Always fail early"   # [ed: the A's are a work in progress]
    ABA = "Always be accurate"
    CBC = "Consistency before cuteness"
    UNO = "Ugly's not okay"
    def inspect
      all = Guidelines.constants
      g = all.collect { |c| '%s="%s"' % [c, const_get(c)] }
      %q{#<Rudy::Guidelines:%s %s>} % [self.object_id, g.join(' ')]
    end
  end
end

puts Rudy::Guidelines.inspect if __FILE__ == $0