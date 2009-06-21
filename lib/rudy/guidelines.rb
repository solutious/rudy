

module Rudy
  module Guidelines
    extend self
    AFE = "Always fail early"
    ABA = "Always be accurate"
    CBC = "Consistency before cuteness"
    UNO = "Ugly's not okay"
    WOC = "Write offensive code"
    def inspect
      all = Guidelines.constants
      g = all.collect { |c| '%s="%s"' % [c, const_get(c)] }
      %q{#<Rudy::Guidelines:0x%s %s>} % [self.object_id, g.join(' ')]
    end
  end
end

puts Rudy::Guidelines.inspect if __FILE__ == $0