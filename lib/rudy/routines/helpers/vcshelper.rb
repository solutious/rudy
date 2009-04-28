
module Rudy; module Routines; 
  module VCSHelper
    include Rudy::Routines::HelperBase
    extend self
    
    # Does the routine config contain VCS routines?
    # Raises Rudy::Error if there is malformed configuration. 
    def vcs?(routine)
      vcsnames = SUPPORTED_VCS_NAMES & routine.keys    # Find intersections.
      return false if vcsnames.empty?                  # Nothing to do. 
      vcsnames.each do |vcs|                          
        routine[vcs].values.each do |p|                # Each VCS should have a
        raise "Bad #{vcs} config" if !p.kind_of?(Hash) # Hash config. Otherwise
        end                                            # it's misconfigured.
      end
      true
    end
    
    def create_vcs_objects(routine)
      return nil unless routine
      vcsnames = SUPPORTED_VCS_NAMES & routine.keys
      vlist = []
      # Look for vcs config in the routine by checking all known vcs types.
      # For each one we'll create an instance of the appropriate VCS class.
      vcsnames.each do |vcs|
        routine[vcs].each_pair do |user,params|
          klass = eval "Rudy::VCS::#{vcs.to_s.upcase}"
          params[:user] = user
          vcs = klass.new(params)
          vcs.raise_early_exceptions    # Raises exceptions for obvious problems.
          vlist << vcs
        end
      end
      vlist
    end
    
  end
end; end