
module Rudy; module Routines; 
  module DependsHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self 
    
    ## NOTE: Dependencies don't use Rudy::Routines.add_helper but we
    ## define them ehere anyway so raise_early_exceptions passes. 
    Rudy::Routines.add_helper :before,  self
    Rudy::Routines.add_helper :after, self
    
    def raise_early_exceptions(type, depends, rset, lbox, argv=nil)
      unless depends.kind_of? Array
        raise Rudy::Error, "#{type} must be a kind of Array (#{depends.class})" 
      end
      raise Rudy::Routines::EmptyDepends, type if depends.nil? || depends.empty?
      depends.flatten.compact.each do |name|
        raise Rudy::Routines::NoRoutine, name unless valid_routine?(name)
      end
    end
    
    # A simple wrapper for executing a routine.
    # * +routine_name+ should be a Symbol representing a routine
    # available to the current machine group.
    # This method finds the handler for the given routine,
    # creates an instance, calls raise_early_exceptions,
    # and finally executes the routine.
    def execute(routine_name)
      handler = Rudy::Routines.get_handler routine_name
      ld "Executing dependency: #{routine_name} (#{handler})"
      routine = handler.new routine_name
      routine.raise_early_exceptions
      routine.execute
    end
    
    # Calls execute for each routine name in +depends+ (an Array).
    # Does nothing if given an empty Array or nil.
    def execute_all(depends)
      return if depends.nil? || depends.empty?
      depends = depends.flatten.compact
      ld "Found depenencies: #{depends.join(', ')}"
      depends.each { |routine| execute(routine) }
    end
    
  end
  
end; end