
module Rudy
  
  # = Rudy::Routines
  # 
  # Every Rudy routine is associated to a handler. There are four standard
  # handler types: Startup, Shutdown, Reboot, and Passthrough. The first 
  # three are associated to routines of the same same. All other routines
  # are handled by Rudy::Routines::Passthrough. 
  # 
  # An individual routine is made up of various actions. Each action is
  # associated to one of the following handlers: depends, disk, script, 
  # user. See each handler for the list of actions it is responsible for. 
  module Routines
    
    require 'rudy/routines/base'
    require 'rudy/routines/handlers/base'
    
    # A Hash of routine names pointing to a specific handler. 
    # See Rudy::Routines.add_routine
    @@routine = {}
    
    # A Hash of routine keywords pointing to a specifc handler.
    # See Rudy::Routines.add_routine
    @@handler = {}
    
    class NoRoutine < Rudy::Error
      def message; "Unknown routine '#{@obj}'"; end
    end
    
    class NoHandler < Rudy::Error
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
    
    # Add a routine handler to @@routine.
    #
    # * +routine_name+ Literally the name of the routine that will 
    #   have a special handler, like startup, shutdown, and reboot.
    # * +handler+ The class that will handle this routine. It must 
    #   inherit Rudy::Routine::Base
    #
    # Returns the value of +handler+.
    def self.add_routine(name, klass)
      add_some_class @@routine, Rudy::Routines::Base, name, klass
    end
    
    # Returns the value in the @@routine associated to the key +routine_name+
    # if it exists, otherwise it returns Rudy::Routines::Passthrough
    def self.get_routine(name)
      get_some_class(@@routine, name) || Rudy::Routines::Passthrough
    end
    
    # Add a routine handler to @@handler.
    def self.add_handler(name, klass)
      add_some_class @@handler, Rudy::Routines::Handlers::Base, name, klass
    end
    
    # Returns the value in the @@handler associated to the key +name+
    # if it exists, otherwise it returns nil
    def self.get_handler(name)
      get_some_class(@@handler, name) || nil
    end
    
    def self.has_routine?(name); @@routine.has_key?(name); end
    def self.has_handler?(name);  @@handler.has_key?(name);  end
    
    # Executes a routine block
    def self.runner(routine, rset, lbox, argv=nil)
      routine.each_pair do |name,definition| 
        handler = Rudy::Routines.get_handler name
        #Rudy::Huxtable.li "  #{name}:".bright
        self.rescue {
          handler.execute(name, definition, rset, lbox, argv)
        }
      end
    end
    
    def self.rescue(ret=nil, &bloc_party)

      begin
        ret = bloc_party.call
      rescue NameError, ArgumentError, RuntimeError, Errno::ECONNREFUSED => ex
        Rudy::Huxtable.le "#{ex.class}: #{ex.message}".color(:red)
        Rudy::Huxtable.le ex.backtrace if Rudy.debug?
        
        unless Rudy::Huxtable.global.parallel
          choice = Annoy.get_user_input('(S)kip  (A)bort: ', nil, 3600) || ''
          if choice.match(/\AS/i)
            # do nothing
          else
            exit 12
          end
         end
      rescue Interrupt
        Rudy::Huxtable.li "Aborting..."
        exit 12
      end
      ret
    end
    
    def self.machine_separator(name, awsid)
      ('%s %-50s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end
    
  private 
  
    # See Rudy::Routines.add_routine
    def self.add_some_class(store, super_klass, name, klass)
      if store.has_key? name
        Rudy::Huxtable.ld "Redefining class for #{name}"
      end
      unless klass.ancestors.member? super_klass
        raise "#{klass} does not inherit #{super_klass}"
      end
      store[name] = klass
    end
    
    # See Rudy::Routines.get_routine
    def self.get_some_class(store, routine_name)
      routine_name &&= routine_name.to_sym
      store[routine_name]
    end
    
    autoload :Passthrough, 'rudy/routines/passthrough'
    autoload :Reboot, 'rudy/routines/reboot'
    autoload :Shutdown, 'rudy/routines/shutdown'
    autoload :Startup, 'rudy/routines/startup'
    
    module Handlers
      autoload :Host, 'rudy/routines/handlers/host'
      autoload :Keypair, 'rudy/routines/handlers/keypair'
      autoload :Machines, 'rudy/routines/handlers/machines'
      autoload :RyeTools, 'rudy/routines/handlers/rye'
      # The following can't be autoloaded because they call
      # Rudy::Routines.add_handler when they're loaded. 
      require 'rudy/routines/handlers/depends'
      require 'rudy/routines/handlers/disks'
      require 'rudy/routines/handlers/group'
      require 'rudy/routines/handlers/script'
      require 'rudy/routines/handlers/user'
    end
  end
end


