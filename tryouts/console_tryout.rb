RUDY_HOME = File.join(File.dirname(__FILE__), '..')
RUDY_LIB = File.join(RUDY_HOME, 'lib')
$:.unshift RUDY_LIB # Put our local lib in first place

require 'yaml'
require 'date'

require 'tryouts'
require 'console'

raise "Sorry Ruby 1.9 only!" unless RUBY_VERSION =~ /1.9/

before do
  @title = "RUDY v0.3"
  @now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
  @props = {
    :zone => "us-east-1b", 
    :environment => "stage",
    :role =>"app", 
    :position => "01"
  }
  # PROMPT_COMMAND
end

after do 
  #Console.clear
end


tryout :positioned do
  Console.print_at(@title, {:y => Cursor.y, :x => Cursor.x })
  sleep 1
  Console.print_at(@now_utc, {:y => Cursor.y, :x => Console.width, :minus => true})  
  puts
  sleep 1
  Console.print_left(@title)
  sleep 1
  Console.print_right(@now_utc)
  puts
  sleep 1
  Console.print_spaced('1'*25, 2, 3, '4'*30, 5, 6)
  puts
  sleep 1
  Console.print_center(Window.bar(50))
  
end

tryout :u_r_d_l do
  puts
  Cursor.up && print('.') 
  sleep 1
  Cursor.right && print('.')
  sleep 1
  Cursor.left && Cursor.down && print('.')
  sleep 1
  Cursor.left(3) && print('.')
end

tryout :update_inplace do
  [(0..11).to_a, (90..110).to_a].flatten.each do |i|
    Console.print_at(i, {:y => Cursor.y, :x => 4 })
    sleep 0.05
  end
  
end


tryout :danger! do
  win = Window.new(:width => 100, :height => 100)
  
  # DEBUGGING: There is a threading bug where the values of props and the
  # string to print are being shared. Make Console and class and give an instance
  # to each thread. However, that could fuck up shit like Cursor.position. 
  
  
  win.static(:right, 0.2, {:y => 0}) do 
    Time.now.utc.strftime("%Y-%m-%d %H:%M:%S").colour(:blue, :white, :underline)
  end
  win.static(:left, 0.2) do 
    rand
  end
  
  win.join_threads
  
  puts $/, "Done!"
  
end


  
  
