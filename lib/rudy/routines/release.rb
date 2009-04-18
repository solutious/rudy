
module Rudy; module Routines;
  class Release < Rudy::Routines::Base

    def execute
      p find_scm(:release)
    end
    
    
  private
    def find_scm(routine)
      env, rol, att = @@global.environment, @@global.role

      # Look for the source control engine, checking all known scm values.
      # The available one will look like [environment][role][release][svn]
      params = nil
      scm_name = nil
      SUPPORTED_SCM_NAMES.each do |v|
        scm_name = v
        params = @@config.routines.find(env, rol, routine, scm_name)
        break if params
      end

      if params
        klass = eval "Rudy::SCM::#{scm_name.to_s.upcase}"
        scm = klass.new(:base => params[:base])
      end

      [scm, params]

    end
    
  end
end;end