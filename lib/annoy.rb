#---
# TODO: Use Matrix to give a more accurate annoyance factor
# TODO: Add trivia questions
#+++

require 'timeout'
require 'sysinfo'
require 'highline'

# = Annoy 
#
# Like your annoying friend that asks you questions all the time.
#
# Rudy uses Annoy to present the user with a simple question before
# continuing with a destructive action. 
#
class Annoy
  
  attr_accessor :factor
  attr_accessor :flavor
  attr_accessor :answer
  attr_accessor :writer
  attr_accessor :period
  attr_accessor :system
  
  @@operators = {
    :low      => %w(+ -),
    :medium   => %w(* -),
    :high     => %w(& * -),
    :insane   => %w(** << | & *)
  }.freeze
  
  @@strlen = {
    :low      => 2,
    :medium   => 3,
    :high     => 4,
    :insane   => 32
  }.freeze
  
  @@randsize = {
    :low      => 10,
    :medium   => 12,
    :high     => 50,
    :insane   => 1000
  }.freeze
  
  @@period = 60.freeze    # max seconds to wait
  @@flavors = [:numeric, :string].freeze
  @@skip = false          # skip questions
  
  # Calling this method tells Annoy to not prompt for
  # a response. All questions will return true. 
  def Annoy.enable_skip; @@skip = true; end
  # Tells annoy to prompt for a response. 
  def Annoy.disable_skip; @@skip = false; end
  # Returns true of Annoy is in skip mode
  def Annoy.skip?; @@skip; end
  
  # * +factor+ annoyance factor, one of :low (default), :medium, :high, :insane
  # * +flavor+ annoyance flavor, one of :rand (default), :numeric, string
  # * +writer+ an IO object to write to. Default: STDERR
  # * +period+ the amount of time to wait in seconds. Default: 60
  def initialize(opts={:factor=>:medium, :flavor=>:rand, :writer=>STDOUT, :period=>nil})
    @factor = opts[:factor]
    @flavor = Annoy.get_flavor(opts[:flavor])
    @writer = opts[:writer]
    @period = opts[:period] || @@period
    unless Annoy.respond_to?("#{@flavor}_question")
      raise "Hey, hey, hey. I don't know that flavor! (#{@flavor})" 
    end
  end
  
  # Generates and returns a question. The correct response is available
  # as +@answer+.
  def question
    q, @answer =Annoy.question(@factor, @flavor)
    q
  end
  
  # A wrapper for string_question and numberic_question
  def Annoy.question(factor=:medium, flavor=:rand)
    raise "Come on, you ruined the flavor!" unless flavor
    Annoy.send("#{flavor}_question", factor)
  end
  
  # Generates a random string
  def Annoy.string_question(factor=:medium)
    # Strings don't need to be evaluated so the answer is the
    # same as the question.
    str = strand @@strlen[factor]
    [str,str]
  end
  
  # * Generates a rudimentary numeric equation in the form: (Integer OPERATOR Integer).
  # * Returns [equation, answer]
  def Annoy.numeric_question(factor=:medium)
    equation = answer = 0
    while answer < 10
      vals = [rand(@@randsize[factor])+1, 
              @@operators[factor][ rand(@@operators[factor].size) ],
              rand(@@randsize[factor])+1 ]
      equation = "(%d %s %d)" % vals
      answer = eval(equation)
    end
    [equation, answer]
  end
  
  # Prints a question to +writer+ and waits for a response on STDIN. 
  # It checks whether STDIN is connected a tty so it doesn't block on gets
  # when there's no human around to annoy. It will return <b>TRUE</b> when
  # STDIN is NOT connected to a tty (when STDIN.tty? returns false).
  # * +msg+ The message to print. Default: "Please confirm."
  # Returns true when the answer is correct, otherwise false.
  def Annoy.challenge?(msg="Please confirm.", factor=:medium, flavor=:rand, writer=STDOUT, period=nil)
    return true unless STDIN.tty? # Humans only!
    return true if Annoy.skip?
    begin
      success = Timeout::timeout(period || @@period) do
        flavor = Annoy.get_flavor(flavor)
        question, answer = Annoy.question(factor, flavor)
        msg = "#{msg} To continue, #{Annoy.verb(flavor)} #{question}: "
        #writer.print msg
        #if ![:medium, :high, :insane].member?(factor) && flavor == :numeric
        #writer.print "(#{answer}) " 
        #writer.flush
        #end
        #response = Annoy.get_response(writer)
                
        highline = HighLine.new 
        response = highline.ask(msg) { |q| 
          q.echo = '*'             # Don't display response
          q.overwrite = true       # Erase the question afterwards
          q.whitespace = :strip    # Remove whitespace from the response
          q.answer_type = Integer  if flavor == :numeric
        }
        
        ret = (response == answer)
        writer.puts "Incorrect" unless ret
        ret
      end
    rescue Interrupt
      writer.puts $/, "Giving up!"
      false
    rescue Annoy::GiveUp => ex
      writer.puts $/, "Giving up!"
      false
    rescue Timeout::Error => ex
      writer.puts $/, "Times up!"
      false
    end
  end
  
  # Runs a challenge with the message, "Are you sure?"
  # See: Annoy.challenge?
  def Annoy.are_you_sure?(factor=:medium, flavor=:rand, writer=STDOUT)
    Annoy.challenge?("Are you sure?", factor, flavor, writer)
  end
  
  # Runs a challenge with the message, "Proceed?"
  # See: Annoy.challenge?
  def Annoy.proceed?(factor=:medium, flavor=:rand, writer=STDOUT)
    Annoy.challenge?("Proceed?", factor, flavor, writer)
  end
  
  # See: Annoy.challenge?
  # Uses the value of @flavor, @factor, and @writer
  def challenge?(msg="Please confirm.")
    Annoy.challenge?(msg, @factor, @flavor, @writer)
  end
  
  # See: Annoy.pose_question
  # Uses the value of @writer
  def pose_question(msg, regexp)
    Annoy.pose_question(msg, regexp, @writer)
  end
  
  # Prints a question to writer and waits for a response on STDIN. 
  # It checks whether STDIN is connected a tty so it doesn't block on gets.
  # when there's no human around to annoy. It will return <b>TRUE</b> when
  # STDIN is NOT connected to a tty.
  # * +msg+ The question to pose to the user
  # * +regexp+ The regular expression to match the answer. 
  def Annoy.pose_question(msg, regexp, writer=STDOUT, period=nil)
    return true unless STDIN.tty? # Only ask a question if there's a human
    return true if Annoy.skip?
    begin
      success = Timeout::timeout(period || @@period) do
        regexp &&= Regexp.new regexp
        writer.print msg 
        writer.flush if writer.respond_to?(:flush)
        response = Annoy.get_response
        regexp.match(response)
      end
    rescue Timeout::Error => ex
      writer.puts $/, "Times up!"
      false
    end
  end
 
  
 private 
  def Annoy.get_response(writer=STDOUT)
    return true unless STDIN.tty? # Humans only
    return true if Annoy.skip?
    # TODO: Count the number of keystrokes to prevent copy/paste.
    # We can probably use Highline. 
    # We likely need to be more specific but this will do for now.
    #if ::SystemInfo.new.os == :unix 
    #  begin
    #    response = []
    #    char = nil
    #    system("stty raw -echo") # Raw mode, no echo
    #    while char != "\r" || response.size > 5
    #      char = STDIN.getc.chr
    #      writer.print char
    #      writer.flush
    #      response << char
    #    end
    #    writer.print "\n\r"
    #    response = response.join('')
    #  rescue => ex
    #  ensure
    #    system("stty -raw echo") # Reset terminal mode
    #  end
    #else
      response = (STDIN.gets || "")
    #end
    response.chomp.gsub(/["']/, '')
  end
  # Returns a verb appropriate to the flavor.
  # * :numeric => resolve
  # * :string => type
  def Annoy.verb(flavor)
    case flavor
    when :numeric then "resolve"
    when :string then "type"
    else
      nil
    end
  end
 
  # 
  # Generates a string of random alphanumeric characters.
  # * +len+ is the length, an Integer. Default: 8
  # * +safe+ in safe-mode, ambiguous characters are removed (default: true):
  #       i l o 1 0
  def Annoy.strand( len=8, safe=true )
     chars = ("a".."z").to_a + ("0".."9").to_a
     chars.delete_if { |v| %w(i l o 1 0).member?(v) } if safe
     str = ""
     1.upto(len) { |i| str << chars[rand(chars.size-1)] }
     str
  end
  
  # * +f+ a prospective flavor name
  def Annoy.get_flavor(f)
    f.to_sym == :rand ? flavor_rand : f.to_sym
  end
  
  # Return a random flavor
  def Annoy.flavor_rand
    @@flavors[rand(@@flavors.size)]
  end

  
end

# = Annoy::GiveUp
#
# This is what happens when you don't answer Annoy's questions. 
class Annoy::GiveUp < RuntimeError
end


