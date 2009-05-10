
module Rudy; module Routines; 
  module DependsHelper
    include Rudy::Routines::HelperBase  # TODO: use execute_rbox_command
    extend self 
    
    def has_depends?(timing, routine)
      (!routine.is_a?(Caesars::Hash) || routine[timing].is_a?(Caesars::Hash))
    end
    
    # Returns an Array of the dependent routines for the given +timing+ (before/after)
    def get(timing, routine)
      return if !(routine.is_a?(Caesars::Hash) || routine[timing].is_a?(Caesars::Hash))
      
      # This will produce an Array containing the routines to run. The 
      # elements are the valid routine names. 
      # NOTE: The "timing" elements are removed from the routines hash. 
      dependencies = []
      routine[timing].each_pair do |n,v| 
        next unless v.nil?  # this skips all "script" blocks
        raise "#{timing}: #{n} is not a known routine" unless valid_routine?(n)
        routine[timing].delete(n)
        dependencies << n
      end

      # We need to return only the keys b/c the values are nil
      dependencies = nil if dependencies.empty?
      dependencies
    end
    

  end
  
end; end