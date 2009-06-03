

module Rudy
  module Routines
    module HelperBase
     include Rudy::Huxtable
     
     def trap_rbox_errors(ret=nil, &command)
       begin
         ret = command.call if command
         return unless ret.is_a?(Rye::Rap)
         puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
         print_response(ret)
       rescue IOError => ex
         STDERR.puts "  Connection Error (#{ex.message})".color(:red)
         choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ')
          if choice.match(/\AS/i)
            return
          elsif choice.match(/\AR/i)
            retry
          else
            exit 12
          end
       rescue Rye::CommandError => ex
         print_response(ex)
         choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ')
          if choice.match(/\AS/i)
            return
          elsif choice.match(/\AR/i)
            retry
          else
            exit 12
          end
       rescue Rye::CommandNotFound => ex
         STDERR.puts "  CommandNotFound: #{ex.message}".color(:red)
         STDERR.puts ex.backtrace if Rudy.debug?
         choice = Annoy.get_user_input('(S)kip  (R)etry  (A)bort: ')
          if choice.match(/\AS/i)
            return
          elsif choice.match(/\AR/i)
            retry
          else
            exit 12
          end
       end
       
       ret
     end
     
     def keep_going?
       Annoy.pose_question("  Keep going?\a ", /yes|y|ya|sure|you bet!/i, STDERR)
     end
     
     # Returns a formatted string for printing command info
     def command_separator(cmd, user, host)
       cmd ||= ""
       cmd, user = cmd.to_s, user.to_s
       prompt = user == "root" ? "#" : "$"
       ("%s@%s%s %s" % [user, host, prompt, cmd.bright])
     end
     
  private 
    def print_response(rap)
      colour = rap.exit_code != 0 ? :red : :normal
      [:stderr].each do |sumpin|
        next if rap.send(sumpin).empty?
        STDERR.puts
        STDERR.puts(("  #{sumpin.to_s.upcase}  " << '-'*38).color(colour).bright)
        STDERR.puts "  " << rap.send(sumpin).join("#{$/}  ").color(colour)
      end
      STDERR.puts "  Exit code: #{rap.exit_code}".color(colour) if rap.exit_code != 0
    end
    
    end
  end
end