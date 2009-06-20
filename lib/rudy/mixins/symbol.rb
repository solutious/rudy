
class Symbol
  unless method_defined? :empty?
    def empty?
      self.to_s.empty?
    end
  end
end