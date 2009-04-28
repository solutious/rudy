

module Rudy
  module Routines
    module HelperBase
     
     def execute_rbox_command(ret=nil, &command)
       begin
         ret = command.call
         print_error(ret) if ret.exit_code != 0
       rescue Rye::CommandError => ex
         print_error(ex)
       end
       
       ret
     end
     
  private 
    def print_error(rap)
      STDERR.puts "  Exit code: #{rap.exit_code}".color(:red)
      
      unless rap.stderr.empty?
        STDERR.puts "  STDERR: #{rap.stderr.join("#{$/}  ")}".color(:red) 
      end
      unless rap.stdout.empty?
        STDERR.puts "  STDOUT: #{rap.stdout.join("#{$/}  ")}".color(:red)
      end
    end
    
    end
  end
end