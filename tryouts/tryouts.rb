
require 'ostruct'

module Tryouts
  
  #    tryout :name do
  #       ...
  #    end
  def tryout(name, &b)
    puts '-'*50
    puts "Running#{@poop}: #{name}"
    begin
      b.call
      sleep 0.1
    rescue Interrupt
    rescue => ex
      STDERR.puts "Tryout error: #{ex.message}"
    end  
      puts $/*2
  end
  
  # Ignore everything
  def xtryout(name, &b)
  end
  
  # Is this wacky syntax useful for anything?
  #    t2 :set .
  #       run = "poop"
  def t2(*args)
    OpenStruct.new
  end
  
end
