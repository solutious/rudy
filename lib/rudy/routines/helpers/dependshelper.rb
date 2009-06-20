
module Rudy; module Routines; 
  module DependsHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self 
    
    ## NOTE: Dependencies don't use Rudy::Routines.add_helper 
    ## Rudy::Routines.add_helper :depends, self
    
    # Returns an Array of the dependent routines for the given +timing+ 
    # which can be anything but is most often one of: :before, :after.
    def get(timing, routine)
      return unless routine.has_key? timing
      # Backwards compatability for 0.8 and earlier which 
      # forced before and after blocks to be Hash objects.
      a = routine[timing].is_a?(Hash) ? routine[timing].keys : routine[timing]
      
      dependencies = []
      a.each do |routine_name|
        # Non-nil values are regular blocks not references
        next unless routine[timing][routine_name].nil?  
        dependencies << routine_name
        # Remove the names of routine dependencies from
        # the routine but leave the ones with values
        # because will be processed by ScriptHandler.
        routine[timing].delete routine_name
        unless valid_routine? routine_name
          raise Rudy::Routines::NoRoutine, routine_name
        end
      end
      
      # We've already deleted the routine references from routine[timing]
      # so it's empty we will delete it too because there is nothing left
      routine.delete(timing) if routine[timing].empty?
      
      ld "Found #{timing} dependencies: #{dependencies.join(', ')}"
      
      dependencies
    end
    
    # A simple wrapper for executing a routine. 
    # * +routine_name+ should be a Symbol representing a routine 
    #   available to the current machine group. 
    # This method finds the handler for the given routine, 
    # creates an instance, calls raise_early_exceptions, 
    # and finally executes the routine. 
    def execute(routine_name)
      handler = Rudy::Routines.get_handler routine_name
      routine = handler.new routine_name
      routine.raise_early_exceptions
      routine.execute
    end
    
    # Calls execute for each routine name in +routines+ (an Array).
    # Does nothing if given an empty Array or nil.
    def execute_all(routines)
      return if routines.nil? || routines.empty?
      routines.each { |routine| execute(routine) }
    end
    
  end
  
end; end