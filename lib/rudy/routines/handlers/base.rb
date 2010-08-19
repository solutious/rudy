

module Rudy; module Routines; module Handlers; 
  module Base
   include Rudy::Huxtable
   
   def trap_rbox_errors(ret=nil, &command)
     begin
       ret = command.call if command
       return unless ret.is_a?(Rye::Rap)
       li '  ' << ret.stdout.join("#{$/}  ") if !ret.stdout.empty?
       print_response(ret)
     rescue IOError => ex
       le "  Connection Error (#{ex.message})".color(:red)
       choice = Annoy.get_user_input('(S)kip  (R)etry  (F)orce  (A)bort: ', nil, 3600) || ''
        if choice.match(/\AS/i)
          return
        elsif choice.match(/\AR/i)
          retry
        elsif choice.match(/\AF/i)
          @@global.force = true
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
   

  private 
    def print_response(rap)
      colour = rap.exit_status != 0 ? :red : :normal
      [:stderr].each do |sumpin|
        next if rap.send(sumpin).empty?
        le
        le(("  #{sumpin.to_s.upcase}  " << '-'*38).color(colour).bright)
        le "  " << rap.send(sumpin).join("#{$/}  ").color(colour)
      end
      le "  Exit code: #{rap.exit_status}".color(colour) if rap.exit_status != 0
    end
  
  end

end; end; end

