

module Rudy
  module Guidelines
    extend self
    CBC = "Consistency before cuteness"
    UNO = "Ugly's not okay"
    AFE = "Always fail early"   # [ed: this is a work in progress]
    def inspect
      all = Guidelines.constants
      g = all.collect { |c| '%s="%s"' % [c, const_get(c)] }
      %q{#<Rudy::Guidelines:%s %s>} % [self.object_id, g.join(' ')]
    end
  end
end

puts Rudy::Guidelines.inspect if __FILE__ == $0