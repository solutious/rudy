

module Rudy
  module Routines
    class Base
      include Rudy::Huxtable
    
      # Examples:
      #
      # def before
      # end
      # def before_local
      # end
      # def svn
      # end
      #
      
      
      #
      #
      def execute
        raise "Override execute method"
      end
      
    end
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routine', '*.rb')


