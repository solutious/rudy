

module Rudy; module Routines; module Handlers; 
  module Base
   include Rudy::Huxtable
   
   def trap_rbox_errors(ret=nil, &command)
     begin
       ret = command.call if command
       return unless ret.is_a?(Rye::Rap)
       puts '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
       print_response(ret)
     rescue IOError => ex
       STDERR.puts "  Connection Error (#{ex.message})".color(:red)
       choice = Annoy.get_user_input('(S)kip  (A)bort: ', nil, 3600) || ''
        if choice.match(/\AS/i)
          return
        #elsif choice.match(/\AR/i)
        #  retry
        else
          exit 12
        end
     end
     
     ret
   end
   
   def keep_going?
     Annoy.pose_question("  Keep going?\a ", /yes|y|ya|sure|you bet!/i, STDERR)
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

end; end; end

