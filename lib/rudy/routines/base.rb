
module Rudy; module Routines;
  class Base
    include Rudy::Huxtable
    
    @@run = true
    
    def self.run?; @@run; end
    def self.disable_run; @@run = false; end
    def self.enable_run; @@run = true; end
    
    def run?; @@run; end
    def disable_run; @@run = false; end
    def enable_run; @@run = true; end
    
      # An Array Rudy::Machines objects that will be processed
    attr_reader :machines
    
    # * +name+ The name of the command specified on the command line
    # * +option+ A Hash or OpenStruct of named command line options. 
    #   If it's a Hash it will be converted to an OpenStruct.
    # * +argv+ An Array of arguments
    #
    # +option+ and +argv+ are made available to the routine block. 
    # 
    #     routines do
    #       magic do |options,argv|
    #         ...
    #       end
    #     end
    #
    def initialize(name=nil, option={}, argv=[], *args)
      name ||= (self.class.to_s.split(/::/)).last.downcase
      option = OpenStruct.new(option) if option.is_a? Hash
      @name, @option, @argv = name.to_sym, option, argv
      a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
      @@sdb ||= Rudy::AWS::SDB.new(a, s, r)
      
      # Grab the routines configuration for this routine name
      # e.g. startup, sysupdate, installdeps
      @routine = fetch_routine_config @name rescue {}
      
      ld "Routine: #{@routine.inspect}"
      
      if @routine
        # Removes the dependencies from the routines hash. 
        # We run these separately from the other actions.
        @before, @after = @routine.delete(:before), @routine.delete(:after)
      end
      
      # Share one Rye::Box instance for localhost across all routines
      unless defined?(@@lbox)
        host, opts = @@global.localhost, { :user => Rudy.sysinfo.user }
        @@lbox = Rudy::Routines::Handlers::RyeTools.create_box host, opts
      end
      
      disable_run if @@global.testrun
      
      # We create these frozen globals for the benefit of 
      # the local and remote routine blocks. 
      $global = @@global.dup.freeze unless $global
      $option = option.dup.freeze unless $option
      
      ## TODO: get the machine config for just the current machine group. This
      ## probably requires Caesars to be aware of which nodes are structural.  
      ##$config = fetch_machine_config unless $config
      
      init(*args) if respond_to? :init
    end
    
    def raise_early_exceptions; raise "Please override"; end
    def execute; raise "Please override"; end
    
  end
  
end; end;