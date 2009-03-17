
require 'timeout'

# Annoy - your annoying friend that asks you questions all the time.
#
# TODO: Use Matrix to give a more accurate annoyance factor
# TODO: Add trivia questions
#
class Annoy
  
  attr_accessor :factor
  attr_accessor :flavor
  attr_accessor :answer
  attr_accessor :writer
  attr_accessor :period
  
  @@operators = {
    :low      => %w(+ - *),
    :medium   => %w(* % + -),
    :high     => %w(* % + -),
    :insane   => %w(** << | & *)
  }.freeze
  
  @@strlen = {
    :low      => 2,
    :medium   => 4,
    :high     => 8,
    :insane   => 32
  }.freeze
  
  @@randsize = {
    :low      => 10,
    :medium   => 100,
    :high     => 1000,
    :insane   => 1000
  }.freeze
  
  @@period = 60.freeze    # max seconds to wait
  
  @@flavors = [:numeric, :string].freeze
  
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
  
  # Prints a question to @writer and waits for a response on STDIN. 
  # It checks whether STDIN is connected a tty so it doesn't block on gets.
  # when there's no human around to annoy. It will return <b>TRUE</b> when
  # STDIN is NOT connected to a tty.
  # * +msg+ The message to print. Default: "Please confirm."
  # Returns true when the answer is correct, otherwise false.
  def Annoy.challenge?(msg="Please confirm.", factor=:medium, flavor=:rand, writer=STDOUT, period=nil)
    return true unless STDIN.tty? # Humans only!
    begin
      success = Timeout::timeout(period || @@period) do
        flavor = Annoy.get_flavor(flavor)
        question, answer = Annoy.question(factor, flavor)
        writer.print "#{msg} To continue, #{Annoy.verb(flavor)} #{question}: "
        writer.print "(#{answer}) " if ![:high, :insane].member?(factor) && flavor == :numeric
        writer.flush
        response = (STDIN.gets || "").chomp.strip.gsub(/["']/, '')
        response = response.to_i if flavor == :numeric
        (response == answer)
      end
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
    begin
      success = Timeout::timeout(period || @@period) do
        regexp &&= Regexp.new regexp
        writer.print msg 
        writer.flush if writer.respond_to?(:flush)
        ans = (STDIN.gets || "").gsub(/["']/, '')
        regexp.match(ans)
      end
    rescue Timeout::Error => ex
      writer.puts $/, "Times up!"
      false
    end
  end
 
 
 private 
  
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



