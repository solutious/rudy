
module Rudy; module Routines; 
  module SCMHelper
    include Rudy::Routines::HelperBase
    extend self
    
    # Does the routine config contain SCM routines?
    # Raises Rudy::Error if there is malformed configuration. 
    def scm?(routine)
      scmnames = SUPPORTED_SCM_NAMES & routine.keys    # Find intersections.
      return false if scmnames.empty?                  # Nothing to do. 
      scmnames.each do |scm|                          
        routine[scm].values.each do |t|                # Each SCM should have a
        raise "Bad #{scm} config" if !t.kind_of?(Hash) # Hash config. Otherwise
        end                                            # it's misconfigured.
      end
      true
    end
    
    def create_scm_objects(routine)
      return nil unless routine
      scmnames = SUPPORTED_SCM_NAMES & routine.keys
      vlist = []
      # Look for scm config in the routine by checking all known scm types.
      # For each one we'll create an instance of the appropriate SCM class.
      scmnames.each do |scm|
        routine[scm].each_pair do |user,params|
          klass = eval "Rudy::SCM::#{scm.to_s.upcase}"
          params[:user] = user
          scm = klass.new(params)
          scm.raise_early_exceptions    # Raises exceptions for obvious problems.
          vlist << scm
        end
      end
      vlist
    end
    
  end
end; end