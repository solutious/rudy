

module Rudy
  module Routines
    
    require 'rudy/routines/base'
    
    # A Hash of routine names pointing to a specific handler. 
    # See Rudy::Routines.add_handler
    @@handler = {}
    
    # A Hash of routine keywords pointing to a specifc helper.
    # See Rudy::Routines.add_helper
    @@helper = {}
    
    class NoRoutine < Rudy::Error
      def message; "Unknown routine '#{@obj}'"; end
    end
    
    class NoHelper < Rudy::Error
      def message; "Unknown routine action '#{@obj}'"; end
    end
    
    # Add a routine handler to @@handler.
    #
    # * +routine_name+ Literally the name of the routine that will 
    #   have a special handler, like startup, shutdown, and reboot.
    # * +handler+ The class that will handle this routine. It must 
    #   inherit Rudy::Routine::Base
    #
    # Returns the value of +handler+.
    def self.add_handler(routine_name, handler)
      add_some_class @@handler, Rudy::Routines::Base, routine_name, handler
    end
    
    # Returns the value in the @@handler associated to the key +routine_name+
    # if it exists, otherwise it returns Rudy::Routines::Passthrough
    def self.get_handler(routine_name)
      get_some_class(@@handler, routine_name) || Rudy::Routines::Passthrough
    end
    
    # Add a routine helper to @@helper.
    def self.add_helper(name, handler)
      add_some_class @@helper, Rudy::Routines::HelperBase, name, handler
    end
    
    # Returns the value in the @@helper associated to the key +name+
    # if it exists, otherwise it returns nil
    def self.get_helper(name)
      get_some_class(@@helper, name) || nil
    end
    
    def self.has_handler?(name); @@handler.has_key?(name); end
    def self.has_helper?(name); @@helper.has_key?(name); end
    
  private 
  
    # See Rudy::Routines.add_handler
    def self.add_some_class(store, klass, routine_name, handler)
      if store.has_key? routine_name
        Rudy::Huxtable.li "Redefining routine handler for #{routine_name}"
      end
      unless handler.ancestors.member? klass
        raise "#{handler} does not inherit #{klass}"
      end
      store[routine_name] = handler
    end
    
    # See Rudy::Routines.get_handler
    def self.get_some_class(store, routine_name)
      routine_name &&= routine_name.to_sym
      store[routine_name]
    end

  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', '*.rb')
Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'routines', 'helpers', '*.rb')

