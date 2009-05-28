

module Rudy
  module SCM
    
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
      
      # copied from routines/helper.rb
      def trap_rbox_errors(ret=nil, &command)
        begin
          ret = command.call
          puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
          print_response(ret)
        rescue Rye::CommandError => ex
          print_response(ex)
          exit 12 unless keep_going?
        rescue Rye::CommandNotFound => ex
          STDERR.puts "  CommandNotFound: #{ex.message}".color(:red)
          STDERR.puts ex.backtrace
          exit 12 unless keep_going?
        end

        ret
      end
      
      
      private 
        def keep_going?
          Annoy.pose_question("  Keep going?\a ", /yes|y|ya|sure|you bet!/i, STDERR)
        end
      
        def print_response(rap)
          [:stderr].each do |sumpin|
            next if rap.send(sumpin).empty?
            STDERR.puts "  #{sumpin}: #{rap.send(sumpin).join("#{$/}  ")}".color(:red)
          end
          STDERR.puts "  Exit code: #{rap.exit_code}".color(:red) if rap.exit_code != 0
        end
        
    end
    
  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'scm', '*.rb')