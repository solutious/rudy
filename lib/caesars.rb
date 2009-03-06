
# Caesars -- A simple class for rapid DSL prototyping.
#
# Subclass Caesars and start drinking! I mean, start prototyping
# your own domain specific language!
#
# See bin/example
#
class Caesars
  VERSION = "0.4.2"
  # A subclass of ::Hash that provides method names for hash parameters.
  # It's like a lightweight OpenStruct. 
  #     ch = Caesars::Hash[:tabasco => :lots!]
  #     puts ch.tabasco  # => lots!
  #
  class Hash < ::Hash
    def method_missing(meth)
      self[meth] if self.has_key?(meth)
    end
    
    # Returns a clone of itself and all children cast as ::Hash objects
    def to_hash(hash=self)
      target = ::Hash[dup]
      hash.keys.each do |key|
        if hash[key].is_a? Caesars::Hash
          target[key] = hash[key].to_hash
          next
        end
        target[key] = hash[key]
      end
      target
    end
    
  end

    # An instance of Caesars::Hash which contains the data specified by your DSL
  attr_accessor :caesars_properties
  
  @@caesars_chilled = []
  
  
  def initialize(name=nil)
    @caesars_name = name if name
    @caesars_properties = Caesars::Hash.new
    @caesars_pointer = @caesars_properties
  end
  
  # Returns an array of the available 
  def keys
    @caesars_properties.keys
  end
  
  def to_hash
    @caesars_properties.to_hash
  end

  # Look for an attribute, bubbling up to the parent if it's not found
  # +criteria+ is an array of attribute names, orders according to their
  # relationship. The last element is considered to the desired attribute.
  # It can be an array.
  #
  #      # Looking for 'attribute'. 
  #      # First checks at @caesars_properties[grandparent][parent][attribute]
  #      # Then, @caesars_properties[grandparent][attribute]
  #      # Finally, @caesars_properties[attribute]
  #      find_deferred('grandparent', 'parent', 'attribute')
  #
  # Returns the attribute if found or nil.
  #
  def find_deferred(*criteria)
    # This is a nasty implementation. Sorry me! I'll enjoy a few
    # caesars and be right with you. 
    att = criteria.pop
    val = nil
    while !criteria.empty?
      str = criteria.collect { |v| "[:'#{v}']" if v }.join
      if att
        str << (att.is_a?(Array) ? att.collect { |v| "[:'#{v}']" if v }.join : "[:'#{att}']")
      end
      val = eval "@caesars_properties#{str} if defined?(@caesars_properties#{str})"
      break if val
      criteria.pop
    end
    # One last try in the root namespace
    val = @caesars_properties[att.to_sym] if defined?(@caesars_properties[att.to_sym]) && !val
    val
  end

  # Act a bit like a hash for the case:
  # @subclass[:property]
  def [](name)
    return @caesars_properties[name] if @caesars_properties.has_key?(name)
    return @caesars_properties[name.to_sym] if @caesars_properties.has_key?(name.to_sym)
  end

  # This method handles all of the attributes that do not contain blocks. 
  # It's used in the DSL for handling attributes dyanamically (that weren't defined
  # previously) and also in subclasses of Caesar for returning the appropriate
  # attribute values. 
  def method_missing(meth, *args, &b)
    return @caesars_properties[meth] if @caesars_properties.has_key?(meth) && args.empty? && b.nil?
    return nil if args.empty? && b.nil?
    
    if b
      # Use the name of the bloody method if no name is supplied. 
      args << meth if args.empty?
      args.each do |name|
        prev = @caesars_pointer
        #(@caesars_pointer[:"#{meth}_values"] ||= []) << name
        @caesars_pointer[name] ||= Caesars::Hash.new
        @caesars_pointer = @caesars_pointer[name]
        b.call if b
        @caesars_pointer = prev
      end
        
    elsif @caesars_pointer.kind_of?(Hash) && @caesars_pointer[meth]
      
      @caesars_pointer[meth] = [@caesars_pointer[meth]] unless @caesars_pointer[meth].is_a?(Array)
      @caesars_pointer[meth] += args
    elsif !args.empty?
      @caesars_pointer[meth] = args.size == 1 ? args.first : args
    end
  
  end

  def self.chill(meth)
    module_eval %Q{
      def #{meth}(*names,&b)
        # caesar.toplevel.unnamed_chilled_attribute
        return @caesars_pointer[:'#{meth}'] if names.empty? && b.nil?
        
        # Use the name of the bloody method if no name is supplied. 
        names << :'#{meth}' if names.empty?
        #{}all = instance_variable_get("@" << #{meth}.to_s) || []
        
        names.each do |name|
          #(@caesars_pointer[:"#{meth}_values"] ||= []) << name
          @caesars_pointer[name] = b
        end
      
        @caesars_pointer[:'#{meth}']
      end
    }
    define_method(:"#{meth}_values") do
      instance_variable_get("@" << meth.to_s) || []
    end
    nil
  end
  # Executes automatically when Caesars is subclassed. This creates the
  # YourClass::DSL module which contains a single method named after YourClass 
  # that is used to catch the top level DSL method. 
  #
  # For example, if your class is called Glasses::HighBall, your top level method
  # would be: highball.
  #
  #      highball :mine do
  #        volume 9.oz
  #      end
  #
  def self.inherited(modname)
    meth = (modname.to_s.split(/::/))[-1].downcase  # Some::ClassName => classname
    module_eval %Q{
      module #{modname}::DSL
        def #{meth}(*args, &b)
          name = !args.empty? ? args.first.to_s : nil
          varname = "@#{meth.to_s}"
          varname << "_\#{name}" if name
          
          # When the top level DSL method is called without a block
          # it will return the appropriate instance variable name
          if b.nil?
            i = instance_variable_get(varname)
          else
            i = instance_variable_set(varname, #{modname.to_s}.new(name))
            i.instance_eval(&b)
          end
          i
        end
        
        def self.methname
          :"#{meth}"
        end
        
      end
    }, __FILE__, __LINE__
  end
  
end
  
  
# A helper for loading a DSL from a config file.
#
# Usage:
#
#      class Staff < Caesars; end;
#      class StaffConfig < Caesars::Config
#        dsl Staff::DSL
#      end
#      @config = StaffConfig.new(:path => '/path/2/staff_dsl.rb')
#      p @config.staff    # => <Staff:0x7ea450 ... >
#
class Caesars::Config
  attr_accessor :path 
  attr_accessor :verbose
  
  @@glasses = []
  
  def initialize(args={:path=>'', :verbose=>false})
    args.each_pair do |n,v|
      self.send("#{n}=", v)
    end
    
    refresh
  end
  
  def empty?
    keys.each do |obj|
      return false if self.respond_to?(obj.to_sym)
    end
    true
  end
  
  def self.dsl(glass)
    @@glasses << glass
  end
  
  def [](name)
    self.send(name) if respond_to?(name)
  end
    
  def keys
    @@glasses.collect { |glass| glass.methname }
  end
  
  # This method is a stub. It gets called by refresh after the 
  # config file has be loaded. You can use it to do some post 
  # processing on the configuration before it's used elsewhere. 
  def postprocess
  end
  
  def refresh
    
    if exists?
      puts "Loading config from #{@path}" if @verbose 
      
      begin
        @@glasses.each { |glass| extend glass }
        dsl = File.read @path
        
        # We're using eval so the DSL code can be executed in this
        # namespace.
        eval %Q{
          #{dsl}
        }
        
        postprocess
        
      rescue SyntaxError => ex
        puts "Syntax error in #{@path}."
        exit 1
      end
    end
  end
  
  def exists?
    File.exists?(@path)
  end
end





