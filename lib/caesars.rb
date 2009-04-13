
# Caesars -- A simple class for rapid DSL prototyping.
#
# Subclass Caesars and start drinking! I mean, start prototyping
# your own domain specific language!
#
# See bin/example
#
class Caesars
  VERSION = "0.5.4"
  @@debug = false

  def Caesars.enable_debug; @@debug = true; end
  def Caesars.disable_debug; @@debug = false; end
  def Caesars.debug?; @@debug; end
  
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
      return hash unless hash.is_a?(Caesars::Hash) # nothing to do
      target = ::Hash[dup]
      hash.keys.each do |key|
        if hash[key].is_a? Caesars::Hash
          target[key] = hash[key].to_hash
          next
        elsif hash[key].is_a? Array
          target[key] = hash[key].collect { |h| to_hash(h) }  
          next
        end
        target[key] = hash[key]
      end
      target
    end
    
  end

    # An instance of Caesars::Hash which contains the data specified by your DSL
  attr_accessor :caesars_properties
  
  
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
  
  # DEPRECATED -- use find_deferred
  #
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
  def find_deferred_old(*criteria)
    # This is a nasty implementation. Sorry me! I'll enjoy a few
    # caesars and be right with you. 
    att = criteria.pop
    val = nil
    while !criteria.empty?
      p [criteria, att].flatten if Caesars.debug?
      val = find(criteria, att)
      break if val
      criteria.pop
    end
    # One last try in the root namespace
    val = @caesars_properties[att.to_sym] if defined?(@caesars_properties[att.to_sym]) && !val
    val
  end
  
  # Look for an attribute, bubbling up through the parents until it's found.
  # +criteria+ is an array of hierarchical attributes, ordered according to 
  # their relationship. The last element is the desired attribute to find.
  # Looking for 'ami':
  #
  #      find_deferred(:environment, :role, :ami)
  #
  # First checks at @caesars_properties[:environment][:role][:ami]
  # Then, @caesars_properties[:environment][:ami]
  # Finally, @caesars_properties[:ami]
  #
  # If the last element is an Array, it's assumed that only that combination
  # should be returned.
  # 
  #      find_deferred(:environment, :role:, [:disks, '/file/path'])
  # 
  # Search order:
  # * [:environment][:role][:disks]['/file/path']
  # * [:environment][:disks]['/file/path']
  # * [:disks]['/file/path']
  #
  # Other nested Arrays are treated special too. We look at the criteria from
  # right to left and remove the first nested element we find.
  #
  #      find_deferred([:region, :zone], :environment, :role, :ami)
  #
  # Search order:
  # * [:region][:zone][:environment][:role][:ami]
  # * [:region][:environment][:role][:ami]
  # * [:environment][:role][:ami]
  # * [:environment][:ami]
  # * [:ami]
  #
  # NOTE: There is a maximum depth of 10. 
  #
  # Returns the attribute if found or nil.
  #
  def find_deferred(*criteria)
    
    # The last element is assumed to be the attribute we're looking for. 
    # The purpose of this function is to bubble up the hierarchy of a
    # hash to find it.
    att = criteria.pop  
    
    # Account for everything being sent as an Array
    # i.e. find([1, 2, :attribute])
    # We don't use flatten b/c we don't want to disturb nested Arrays
    if criteria.empty?
      criteria = att
      att = criteria.pop
    end
    
    found = nil
    sacrifice = nil
    
    while !criteria.empty?
      found = find(criteria, att)
      break if found

      # Nested Arrays are treated special. We look at the criteria from
      # right to left and remove the first nested element we find.
      #
      # i.e. [['a', 'b'], 1, 2, [:first, :second], :attribute]
      #
      # In this example, :second will be removed first.
      criteria.reverse.each_with_index do |el,index|
        next unless el.is_a?(Array)    # Ignore regular criteria
        next if el.empty?              # Ignore empty nested hashes
        sacrifice = el.pop
        break
      end

      # Remove empty nested Arrays
      criteria.delete_if { |el| el.is_a?(Array) && el.empty? }

      # We need to make a sacrifice
      sacrifice = criteria.pop if sacrifice.nil?
      break if (limit ||= 0) > 10  # A failsafe
      limit += 1
      sacrifice = nil
    end

    found || find(att)  # One last try in the root namespace
  end
  
  # Looks for the specific attribute specified. 
  # +criteria+ is an array of attribute names, orders according to their
  # relationship. The last element is considered to the desired attribute.
  # It can be an array.
  #
  # Unlike find_deferred, it will return only the value specified, otherwise nil. 
  def find(*criteria)
    criteria.flatten! if criteria.first.is_a?(Array)
    p criteria if Caesars.debug?
    # BUG: Attributes can be stored as strings and here we only look for symbols
    str = criteria.collect { |v| "[:'#{v}']" if v }.join
    eval_str = "@caesars_properties#{str} if defined?(@caesars_properties#{str})"
    val = eval eval_str
    val
  end
  
  # Act a bit like a hash for the case:
  # @subclass[:property]
  def [](name)
    return @caesars_properties[name] if @caesars_properties.has_key?(name)
    return @caesars_properties[name.to_sym] if @caesars_properties.has_key?(name.to_sym)
  end
  
  # Act a bit like a hash for the case:
  # @subclass[:property] = value
  def []=(name, value)
    @caesars_properties[name] = value
  end
  
  # This method handles all of the attributes that do not contain blocks. 
  # It's used in the DSL for handling attributes dyanamically (that weren't defined
  # previously) and also in subclasses of Caesar for returning the appropriate
  # attribute values. 
  def method_missing(meth, *args, &b)
    # Handle the setter, attribute=
    if meth.to_s =~ /=$/ && @caesars_properties.has_key?(meth.to_s.chop.to_sym)
      return @caesars_properties[meth.to_s.chop.to_sym] = (args.size == 1) ? args.first : args
    end
    
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
        begin
          b.call if b
        rescue ArgumentError, SyntaxError => ex
          STDERR.puts "CAESARS: error in #{meth} (#{args.join(', ')})" 
          raise ex
        end
        @caesars_pointer = prev
      end
        
    elsif @caesars_pointer.kind_of?(Hash) && @caesars_pointer[meth]
      
      @caesars_pointer[meth] = [@caesars_pointer[meth]] unless @caesars_pointer[meth].is_a?(Array)
      @caesars_pointer[meth] += args
    elsif !args.empty?
      @caesars_pointer[meth] = args.size == 1 ? args.first : args
    end
  
  end
  
  # A class method which can be used by subclasses to specify which methods 
  # should delay execution of their blocks. Here's an example:
  # 
  #      class Food < Caesars
  #        chill :count
  #      end
  #      
  #      food do
  #        taste :delicious
  #        count do |items|
  #          puts items + 2
  #        end
  #      end
  #
  #      @config.food.count.call(3)     # => 5
  #
  def self.chill(caesars_meth)
    module_eval %Q{
      def #{caesars_meth}(*caesars_names,&b)
        # caesars.toplevel.unnamed_chilled_attribute
        return @caesars_properties[:'#{caesars_meth}'] if @caesars_properties.has_key?(:'#{caesars_meth}') && caesars_names.empty? && b.nil?
        
        # Use the name of the chilled method if no name is supplied. 
        caesars_names << :'#{caesars_meth}' if caesars_names.empty?
        
        caesars_names.each do |name|
          @caesars_pointer[name] = b
        end
      
        @caesars_pointer[:'#{caesars_meth}']
      end
    }
    nil
  end
  
  
  
  # Force the specified keyword to always be treated as a hash. 
  # Example:
  #
  #     startup do
  #       disks do
  #         create "/path/2"         # Available as hash: [action][disks][create][/path/2] == {}
  #         create "/path/4" do      # Available as hash: [action][disks][create][/path/4] == {size => 14}
  #           size 14
  #         end
  #       end
  #     end
  #
  def self.forced_hash(caesars_meth, &b)
    module_eval %Q{
      def #{caesars_meth}(*caesars_names,&b)
        if @caesars_properties.has_key?(:'#{caesars_meth}') && caesars_names.empty? && b.nil?
          return @caesars_properties[:'#{caesars_meth}'] 
        end
        
        return nil if caesars_names.empty? && b.nil?
        return method_missing(:'#{caesars_meth}', *caesars_names, &b) if caesars_names.empty?

        caesars_name = caesars_names.shift

        prev = @caesars_pointer
        @caesars_pointer[:'#{caesars_meth}'] ||= Caesars::Hash.new
        hash = Caesars::Hash.new
        @caesars_pointer = hash
        b.call if b
        @caesars_pointer = prev
        @caesars_pointer[:'#{caesars_meth}'][caesars_name] = hash 
        @caesars_pointer = prev
      end
    }
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
  #        volume "9oz"
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
          inst = instance_variable_get(varname)
          
          # When the top level DSL method is called without a block
          # it will return the appropriate instance variable name
          return inst if b.nil?
          
          # Add to existing instance, if it exists. Otherwise create one anew.
          inst = instance_variable_set(varname, inst || #{modname.to_s}.new(name))
          inst.instance_eval(&b)
          inst
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
  attr_accessor :paths
  attr_accessor :options
  attr_accessor :verbose
  
  @@glasses = []
  
  # +args+ is a last of config file paths to load into this instance.
  # If the last argument is a hash, it's assumed to be a list of 
  # options. The available options are:
  #
  # <li>:verbose => true or false</li>
  #
  def initialize(*args)
    # We store the options hash b/c we reapply them when we refresh.
    @options = args.last.is_a?(Hash) ? args.pop : {}
    @paths = args.empty? ? [] : args
    @options = {}
    
    refresh
  end
  
  def caesars_init
    # Remove instance variables used to populate DSL data
    instance_variables.each do |varname|
      next if varname == :'@options' || varname == :'@paths'  # Ruby 1.9.1
      next if varname == '@options' || varname == '@paths'  # Ruby 1.8
      instance_variable_set(varname, nil)
    end
    
    # Re-apply options
    @options.each_pair do |n,v|
      self.send("#{n}=", v) if respond_to?("#{n}=")
    end
    
    check_paths     # make sure files exist
  end
  
  # This method is a stub. It gets called by refresh after the 
  # config file has be loaded. You can use it to do some post 
  # processing on the configuration before it's used elsewhere. 
  def postprocess
  end
  
  def refresh
    caesars_init
    
    @paths.each do |path|
      puts "Loading config from #{path}" if @verbose 
      
      begin
        @@glasses.each { |glass| extend glass }
        dsl = File.read path
        
        # We're using eval so the DSL code can be executed in this
        # namespace.
        eval %Q{
          #{dsl}
        }, binding, __FILE__, __LINE__
        
        postprocess
        
      rescue ArgumentError, SyntaxError => ex
        puts "Syntax error in #{path}."
        puts ex.message
        puts ex.backtrace if Caesars.debug?
        exit 1
      end
    end
  end
  
  def check_paths
    @paths.each do |path|
      raise "You provided a nil value" unless path
      raise "Config file #{path} does not exist!" unless File.exists?(path)
    end
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
  
end



