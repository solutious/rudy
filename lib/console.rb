#---
# Adapted from: http://github.com/oneup/ruby-console/tree/tput
# See: http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
# See: man terminfo
#+++

#
#
#
class String
  @@print_with_attributes = true
  def String.disable_colour; @@print_with_attributes = false; end
  def String.disable_color;  @@print_with_attributes = false; end
  def String.enable_colour;  @@print_with_attributes = true;  end
  def String.enable_color;   @@print_with_attributes = true;  end
  
  # +col+, +bgcol+, and +attribute+ are symbols corresponding
  # to Console::COLOURS, Console::BGCOLOURS, and Console::ATTRIBUTES.
  # Returns the string in the format attributes + string + defaults.
  #
  #     "MONKEY_JUNK".colour(:blue, :white, :blink)  # => "\e[34;47;5mMONKEY_JUNK\e[39;49;0m"
  #
  def colour(col, bgcol = nil, attribute = nil)
    return self unless @@print_with_attributes
    Console.style(col, bgcol, attribute) +
    self +
    Console.style(:default, :default, :default)
  end
  alias :color :colour
  
  # See colour
  def bgcolour(bgcol = :default)
    return self unless @@print_with_attributes
    Console.style(nil, bgcol, nil) +
    self +
    Console.style(nil, :default, nil)
  end
  alias :bgcolor :bgcolour
  
  # See colour
  def att(a = :default)
    return self unless @@print_with_attributes
    Console.style(nil, nil, a) +
    self +
    Console.style(nil, nil, :default)
  end
  
  # Shortcut for att(:bright)
  def bright
    att(:bright)
  end
  
  # Print the string at +x+ +y+. When +minus+ is any true value
  # the length of the string is subtracted from the value of x
  # before printing. 
  def print_at(x=nil, y=nil, minus=false)
    args = {:minus=>minus}
    args[:x] &&= x
    args[:y] &&= y
    Console.print_at(self, args)
  end
  
  # Returns the string with ANSI escape codes removed.
  #
  # NOTE: The non-printable attributes count towards the string size. 
  # You can use this method to get the "visible" size:
  #
  #     "\e[34;47;5mMONKEY_JUNK\e[39;49;0m".noatt.size      # => 11
  #     "\e[34;47;5mMONKEY_JUNK\e[39;49;0m".size            # => 31
  #
  def noatt
    gsub(/\e\[?[0-9;]*[mc]?/, '')
  end
  alias :noansi :noatt
  
end

class Object #:nodoc:all

  # Executes tput +capnam+ with +args+. Returns true if tcap gives
  # 0 exit status and false otherwise. 
  # 
  #     tput :cup, 1, 4
  #     $ tput cup 1 4
  #
  def tput(capnam, *args)
    system("tput #{capnam} #{args.flatten.join(' ')}")
  end
  
  # Executes tput +capnam+ with +args+. Returns the output of tput.
  # 
  #     tput_val :cols  # => 16
  #     $ tput cols     # => 16
  #
  def tput_val(capnam, *args)
    `tput #{capnam} #{args.flatten.join(' ')}`.chomp
  end
end



module Console #:nodoc:all
  extend self
  require 'timeout'
  require 'thread'
  
  # ANSI escape sequence numbers for text attributes
  ATTRIBUTES = {
    :normal     => 0,
    :bright     => 1,
    :dim        => 2,
    :underline  => 4,
    :blink      => 5,
    :reverse    => 7,
    :hidden     => 8,
    :default    => 0,
  }.freeze unless defined? ATTRIBUTES
  
  # ANSI escape sequence numbers for text colours
  COLOURS = {
    :black   => 30,
    :red     => 31,
    :green   => 32,
    :yellow  => 33,
    :blue    => 34,
    :magenta => 35,
    :cyan    => 36,
    :white   => 37,
    :default => 39,
    :random  => 30 + rand(10).to_i
  }.freeze unless defined? COLOURS
  
  # ANSI escape sequence numbers for background colours
  BGCOLOURS = {
    :black   => 40,
    :red     => 41,
    :green   => 42,
    :yellow  => 43,
    :blue    => 44,
    :magenta => 45,
    :cyan    => 46,
    :white   => 47,
    :default => 49,
    :random  => 40 + rand(10).to_i
  }.freeze unless defined? BGCOLOURS
  
  def valid_colour?(colour)
    COLOURS.has_key? colour
  end
  alias :valid_color? :valid_colour? 
  
  def print_left(str, props={})
    props[:x] ||= 0
    props[:y] ||= Cursor.y
#    print_at("x:#{props[:x]} y:#{props[:y]}", {:x => 0, :y => 10})
    print_at(str, props)
  end
  def print_right(str, props={})
    props[:x] ||= width
    props[:y] ||= Cursor.y
    props[:minus] = true unless props.has_key?(:minus)
    print_at(str, props)  
  end
  def print_spaced(*args)
    props = (args.last.is_a? Hash) ? args.pop : {}
    props[:y] = Cursor.y
    chunk_width = (width / args.flatten.size).to_i
    chunk_at = 0
    args.each do |chunk|
      props[:x] = chunk_at
      print_at(chunk.to_s[0, chunk_width], props)
      chunk_at += chunk_width
    end
    puts
  end
  def print_center(str, props={})
    props[:x] = ((width - str.noatt.length) / 2).to_i-1
    props[:y] ||= height
    print_at(str, props)
  end
  def print_at(str, props={})
    print_at_lamb = lambda {
      props[:x] ||= 0
      props[:y] ||= 0
      props[:minus] = false unless props.has_key?(:minus)
      props[:x] = props[:x]-str.noatt.size if props[:x] && props[:minus] # Subtract the str length from the position
      Cursor.save
      Cursor.move = 0
      print str
      Cursor.restore
    }
    RUBY_VERSION =~ /1.9/ ? Thread.exclusive(&print_at_lamb) : print_at_lamb.call
  end
  
  def self.style(col, bgcol=nil, att=nil)
    valdor = []
    valdor << COLOURS[col] if COLOURS.has_key?(col)
    valdor << BGCOLOURS[bgcol] if BGCOLOURS.has_key?(bgcol)
    valdor << ATTRIBUTES[att] if ATTRIBUTES.has_key?(att)
    "\e[#{valdor.join(";")}m"   # => \e[8;34;42m  
  end
  
  def self.clear
    tput :clear
  end

  def reset
    tput :reset
  end
  
  def width
    tput_val(:cols).to_i
  end

  def height
    tput_val(:lines).to_i
  end
end

module Cursor #:nodoc:all
  extend self
  
  # Returns [x,y] for the current cursor position.
  def position
    yx = [0,0]
    
    position_lamb = lambda {
      begin
        # NOTE: Can we get cursor position from tput?
        termsettings = `stty -g`
      
        # DEBUGGING: The following code works in Ruby 1.9 but not 1.8.
      
        system("stty raw -echo")
        print "\e[6n"  # Forces output of: \e[49;1R  (\e is not printable)
        c = ''
        (pos ||= '') << c while (c = STDIN.getc) != 'R'# NOTE: There must be a better way!
        yx = pos.scan(/(\d+);(\d+)/).flatten
        yx[0] = yx[0].to_i - 1  # It returns 1 for the first column, but we want 0
        yx[1] = yx[1].to_i - 1
      ensure
        system("stty #{termsettings}") # Get out of raw mode
      end
    }
    
    RUBY_VERSION =~ /1.9/ ? Thread.exclusive(&position_lamb) : position_lamb.call
    yx.reverse
  end

  def x; position[0]; end
  def y; position[1]; end

  def move=(*args)
    x,y = *args.flatten
    tput(:cup, y, x) # "tput cup" takes y before x
  end

  def up(n=1)
    tput :cuu, n
  end

  def down(n=1)
    tput :cud, n
  end

  def right(x=1)
    tput :cuf, x
  end

  def left(x=1)
    tput :cub, x
  end
  
  def line(n=1)
    tput :il, n
  end
  
  def save
    tput :sc
  end

  def restore
    tput :rc
  end
  
  def clear_line
    tput :el
  end
  
  # TODO: replace methods with this kinda thing
  #@@capnames = {
  #  :restore => [:rc],
  #  :save => [:sc],
  #  :clear_line => [:el],
  #  :line => [:il, 1, 1],
  #  
  #  :up => [:cuu, 1, 1],
  #  :down => [:cud, 1, 1],
  #  :right => [:cuf, 1, 1],
  #  :left => [:cub, 1, 1],
  #  
  #  :move => [:cup, 2, 0, 0]
  #}
  #
  #@@capnames.each_pair do |meth, cap|
  #  module_eval <<-RUBY
  #    def #{meth}(*args)
  #      tput '#{cap[0]}'
  #    end
  #  RUBY
  #end
  
end

class Window #:nodoc:all
  attr_accessor :row, :col, :width, :height, :text, :fg, :bg
  attr_reader :threads
  
  def initialize(*args)
    @row = 1
    @col = 1
    @width = 10
    @height = 5
    @text = ""
    @fg = :default
    @bg = :default
    @threads = []
  end

  def position=(x,y=nil)
    @x = x
    @y = y if y
  end

  def position
    [@row, @col]
  end
  
  def self.bar(len, unit='=')
    unit*len
  end

  
  # Execute the given block every +n+ seconds in a separate thread.
  # The lower limit for +n+ is 1 second. 
  # Returns a Thread object.
  def every_n_seconds(n)
    #n = 1 if n < 1
    thread = Thread.new do
      
      begin
        while true
          before = Time.now
          yield
          interval = n - (Time.now - before)
          sleep(interval) if interval > 0
        end
      rescue Interrupt
        break
      ensure
        thread
      end
    end
  end
  
  # Print text to the screen via +type+ every +refresh+ seconds. 
  # Print the return value of the block to the screen using the
  # print_+type+ method. +refresh+ is number of seconds to wait
  # +props+ is the hash sent to print_+type+. 
  # Returns a Thread object.
  #
  #     # Print the time in the upper right corner every second
  #     thread1 = Console.static(:right, 1, {:y => 0}) do 
  #       Time.now.utc.strftime("%Y-%m-%d %H:%M:%S").colour(:blue, :white, :underline)
  #     end
  #
  def static(type, refresh=2, props={}, &b)
    meth = "print_#{type}"
    raise "#{meth} is not supported" unless Console.respond_to?(meth)
    
    refresh ||= 0
    refreh = refresh.to_s.to_i
    
    thread = every_n_seconds(refresh) do 
      Console.send(meth, b.call, props.clone) 
    end
    
    @threads << thread
    
    thread
  end
  
  def join_threads
    begin
      @threads.each do |t|
        t.join
      end
    rescue Interrupt
    ensure
      @threads.each do |t|
        t.kill
      end
    end
  end
  
end
