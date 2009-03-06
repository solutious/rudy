
require 'ostruct'

module Tryouts
  
  def before(&b)
    b.call
  end
  def after(&b)
    at_exit &b
  end
  
  
  #    tryout :name do
  #       ...
  #    end
  def tryout(name, &b)
    puts "Running#{@poop}: #{name}"
    begin
      b.call
      puts $/*2
      sleep 1
    rescue Interrupt
    end
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

include Tryouts