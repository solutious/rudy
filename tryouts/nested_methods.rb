

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