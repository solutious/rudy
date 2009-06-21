
module Rudy
  
  # = Rudy::Routines
  # 
  # Every Rudy routine is associated to a handler. There are four standard
  # handler types: Startup, Shutdown, Reboot, and Passthrough. The first 
  # three are associated to routines of the same same. All other routines
  # are handled by Rudy::Routines::Passthrough. 
  # 
  # An individual routine is made up of various actions. Each action is
  # associated to one of the following helpers: depends, disk, script, 
  # user. See each helper for the list of actions it is responsible for. 
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
    
    class EmptyDepends < Rudy::Error
      def message; "Empty depends block in routine."; end
    end
    
    class GroupNotRunning < Rudy::Error
      def message; "Some machines are not running:#{$/}#{@obj.inspect}"; end
    end
    
    class GroupNotAvailable < Rudy::Error
      def message; "Some machines are not available:#{$/}#{@obj.inspect}"; end
    end
    
    class UnsupportedActions < Rudy::Error
      def initialize(klass, actions)
        @klass, @actions = klass, [actions].flatten
      end
      def message; "#{@klass} does not support: #{@actions.join(', ')}"; end
    end
    
    # Add a routine handler to @@handler.
    #
    # * +routine_name+ Literally the name of the routine that will 
    #   have a special handler, like startup, shutdown, and reboot.
    # * +handler+ The class that will handle this routine. It must 
    #   inherit Rudy::Routine::Base
    #
    # Returns the value of +handler+.
    def self.add_handler(routine_name, klass)
      add_some_class @@handler, Rudy::Routines::Base, routine_name, klass
    end
    
    # Returns the value in the @@handler associated to the key +routine_name+
    # if it exists, otherwise it returns Rudy::Routines::Passthrough
    def self.get_handler(routine_name)
      get_some_class(@@handler, routine_name) || Rudy::Routines::Passthrough
    end
    
    # Add a routine helper to @@helper.
    def self.add_helper(action_name, klass)
      add_some_class @@helper, Rudy::Routines::HelperBase, action_name, klass
    end
    
    # Returns the value in the @@helper associated to the key +name+
    # if it exists, otherwise it returns nil
    def self.get_helper(action_name)
      get_some_class(@@helper, action_name) || nil
    end
    
    def self.has_handler?(name); @@handler.has_key?(name); end
    def self.has_helper?(name);  @@helper.has_key?(name);  end
    
    # Executes a routine block
    def self.runner(routine, rset, lbox, option=nil, argv=nil)
      routine.each_pair do |action,definition| 
        helper = Rudy::Routines.get_helper action
        Rudy::Huxtable.ld "  executing helper: #{action}"
        Rudy::Routines.rescue {
          helper.execute(action, definition, rset, lbox, option, argv)
        }
      end
    end
    
    def self.rescue(ret=nil, &bloc_party)
      begin
        ret = bloc_party.call
      rescue => ex
        unless Rudy::Huxtable.global.parallel
          STDERR.puts "  #{ex.class}: #{ex.message}".color(:red)
          STDERR.puts ex.backtrace if Rudy.debug?
          choice = Annoy.get_user_input('(S)kip  (A)bort: ') || ''
          if choice.match(/\AS/i)
            # do nothing
          else
            exit 12
          end
         end
      rescue Interrupt
        puts "Aborting..."
        exit 12
      end
      ret
    end
    
    def self.machine_separator(name, awsid)
      ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end
    
  private 
  
    # See Rudy::Routines.add_handler
    def self.add_some_class(store, super_klass, name, klass)
      if store.has_key? name
        Rudy::Huxtable.li "Redefining class for #{name}"
      end
      unless klass.ancestors.member? super_klass
        raise "#{klass} does not inherit #{super_klass}"
      end
      store[name] = klass
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

