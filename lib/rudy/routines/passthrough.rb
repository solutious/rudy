

module Rudy; module Routines;
  class Passthrough < Rudy::Routines::Base
    
    def init(*args)
      @routine = fetch_routine_config @name
    end
    
    # * +each_mach+ is an optional block which is executed between 
    # disk creation and the after scripts. The will receives two 
    # arguments: instances of Rudy::Machine and Rye::Box.
    def execute(&each_mach)
      ld "Executing routine: #{@name}"
      processed = []
      generic_routine_wrapper do |action,defintion|
        raise NoHelper, action unless Rudy::Routines.has_helper?(action)
        ld "Executing routine helper: #{action}"
        helper = Rudy::Routines.get_helper action
        p machines
        #helper.can?
        #helper.execute(action, definition, @lbox)
        #p [@name, action, helper]
      end
      processed
    end
    
    ##### remote_user = (fetch_machine_param(:user) || :root).to_s
    
    def generic_routine_wrapper(&routine_action)
      
      routine ||= @routine
      raise "No routine supplied" unless routine.kind_of?(Hash)
            
      # Declare a couple vars so they're available outide the block
      before_deps = after_deps = nil  

      # This gets and removes the dependencies from the routines hash.
      # We grab the after ones now too, so they can also be removed.
      before_deps = Rudy::Routines::DependsHelper.get(:before, routine)
      after_deps  = Rudy::Routines::DependsHelper.get(:after,  routine) 
      
      Rudy::Routines::DependsHelper.execute_all before_deps
      
      # This is the meat of the sandwich
      if routine_action && run?
        routine.each_pair { |action,defenition| 
          routine_action.call action, defenition
        }
      end
      
      Rudy::Routines::DependsHelper.execute_all after_deps
      
    end
    
    # Called by generic_machine_runner
    def raise_early_exceptions
      raise Rudy::Error, "No routine name" unless @name
      raise NoRoutine, @name unless @routine
      # TODO: enable this for EC2 groups only
      #raise Rudy::PrivateKeyNotFound, root_keypairpath unless has_keypair?(:root)
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      ##rmach = Rudy::Machines.new
      ##if !@@global.offline && !rmach.running?
      ##  raise MachineGroupNotRunning, current_machine_group
      ##end
    end
    
  end

end; end