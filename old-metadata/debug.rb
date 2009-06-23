

module Rudy; module MetaData
class Debug
  include Rudy::MetaData
  
  def init
  end
  
  def list(more=[], less=[], local={}, &block)
    objects = list_as_hash(more, less, local, &block)
    objects &&= objects.values
    objects
  end

  def list_as_hash(more=[], less=[], local={}, &block)
    query = to_select(more, less, local)
    list = @sdb.select(query) || {}
    objects = {}
    list.each_pair do |n,d|
      objects[n] = d
    end
    objects.each_pair { |n,obj| block.call(obj) } if block
    objects = nil if objects.empty?
    objects
  end
  
  
  def to_select(more, less, local)
    query = super(more, less, local)
#    query << " order by created desc"
    puts query if @@global.verbose > 0
    query
  end
  
end
end; end

