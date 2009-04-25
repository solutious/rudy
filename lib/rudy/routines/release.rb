
module Rudy; module Routines;
  class Release < Rudy::Routines::Base

    def execute
      routine = fetch_routine_config(:release)
      scm = find_scm(routine)
      
      # Release piggy-backs on the the Startup routine. 
      rr = Rudy::Routines::Startup.new
      rr.execute(routine) do |machine,rbox|
        puts "Release #{machine.name}"
      end
    end
    
  private
    def find_scm(routine)
      return nil unless routine
      
      # Look for the source control engine, checking all known scm values.
      # The available one will be a key of the routine hash
      scm_name, params = nil, nil
      SUPPORTED_SCM_NAMES.each do |v|
        next unless routine.has_key?(v)
        scm_name, params = v, routine[v]
        break
      end
      if params
        klass = eval "Rudy::SCM::#{scm_name.to_s.upcase}"
        scm = klass.new(:base => params[:base])
      end
      [scm, params]
    end
    
  end
end;end