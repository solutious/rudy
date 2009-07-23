

module Rudy
  
  module Machines
    extend self
    include Rudy::Huxtable
   
    def get(position)
      tmp = Rudy::Machine.new position
      record = Rudy::Metadata.get tmp.name
      return nil unless record.is_a?(Hash)
      tmp.from_hash record
    end
    
    def find_next_position
      raise "reimplement by looking at position values"
      list = Rudy::Machine.list({}, [:position]) || []
      pos = list.size + 1
      pos.to_s.rjust(2, '0')
    end
    
    def running?(pos)
      if pos.is_a? Range
        raise "to implement"
      else
        !get(pos).nil?
      end
    end
    
    def create(size=3)
      size ||= Rudy::Huxtable.current_machine_count.to_i
      group = Array.new(size) do |i|
        m = Rudy::Machine.new(i + 1)
        m.create
        m
      end
    end
    
  end
  
end