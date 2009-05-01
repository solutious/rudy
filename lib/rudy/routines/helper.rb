

module Rudy
  module Routines
    module HelperBase
     
     def execute_rbox_command(ret=nil, &command)
       begin
         ret = command.call
         puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
         print_response(ret)
       rescue Rye::CommandError => ex
         print_response(ex)
         unless Annoy.proceed?(:low, :string)
           exit 12
         end
       rescue Rye::CommandNotFound => ex
         STDERR.puts "  CommandNotFound: #{ex.message}".color(:red)
         STDERR.puts ex.backtrace if Rudy.debug?
       end
       
       ret
     end
     
     # Returns a formatted string for printing command info
     def command_separator(cmd, user)
       cmd ||= ""
       cmd, user = cmd.to_s, user.to_s
       prompt = user == "root" ? "#" : "$"
       ("%s%s%s %s" % [$/, user, prompt, cmd.bright])
     end
     
  private 
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