
## Example 2

class Helper
  attr_accessor :worker
  def metaclass
    (class << self; self; end)
  end

  def meta_eval &block
    metaclass.instance_eval &block
  end
  
  def add_method(meth)
    meta_eval do
      define_method( meth ) do |val|
        @worker2 = val if val
        val
      end
    end
  end
end

h = Helper.new
h.worker = true
h.add_method(:worker2)
h.worker2(1)



__END__

## Example 1 -- test3 is not available until after test2 is called
module Helper

  def test1
    puts "test1"

    def test2
      def test3
        puts "AWESOME"
      end
      
      puts "test2"
      yield
    end
    
    def test3
      puts "test3"
    end
    yield
  end
  
end

include Helper

test1 do 
  puts "1"
  test3      # => test3
  test2 do 
    test3    # => AWESOME
    puts "2"
  end
end

# test2    # => throws error

__END__

## Sam's example -- "there" is available to the entire method after hello is called. 

class Foo

  def machines
    puts '1'
  end
  
  def ami
    puts '2'
  end
  
end


class Bar
  
  def hello
    def there
      puts '3'
    end
  end
end


Foo.new.machines
Foo.new.ami
Bar.new.hello

Bar.new.there
Bar.new.there

#class << self;