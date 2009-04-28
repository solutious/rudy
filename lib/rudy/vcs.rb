

module Rudy
  module VCS
    
    class NotAWorkingCopy < Rudy::Error
      def message
        "Not the root directory of a #{@obj} working copy"
      end
    end
    class CannotCreateTag < Rudy::Error
      def message
        "There was an unknown problem creating a release tag (#{@obj})"
      end
    end
    class DirtyWorkingCopy < Rudy::Error
      def message
        "Please commit local #{@obj} changes"
      end
    end
    class RemoteError < Rudy::Error; end
    class NoRemoteURI < Rudy::Error; end
    class TooManyTags < Rudy::Error
      def message; "Too many tag creation attempts!"; end
    end
    class NoRemotePath < Rudy::Error
      def message 
        "Add a path for #{@obj} in your routines config"
      end
    end
    
    
    module ObjectBase
      
      
      def raise_early_exceptions; raise "override raise_early_exceptions"; end
      
      
    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'vcs', '*.rb')