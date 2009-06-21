
module Rudy; module Routines; 
  module HostnameHelper
    include Rudy::Routines::HelperBase  # TODO: use trap_rbox_errors
    extend self 
    
    ## NOTE: This helper doesn't use Rudy::Routines.add_helper
    
    def set_hostname(rset)
      # Set the hostname if specified in the machines config. 
      # :rudy -> change to Rudy's machine name
      # :default -> leave the hostname as it is
      # Anything else other than nil -> change to that value
      # NOTE: This will set hostname every time a routine is
      # run so we may want to make this an explicit action.
      rset.boxes.each do |rbox|
        Rudy::Routines.rescue {
          hn = current_machine_hostname || :rudy
          if hn != :default
            hn = rbox.stash.name if hn == :rudy
            lip "Setting hostname to #{hn}... "
            rbox.hostname(hn) 
            li "done"
          end
        }
      end
    end
    
  end
end; end