


module Rudy
  module Command
    class Environment < Rudy::Command::Base
      
      #---
      # TODO: http://net-ssh.rubyforge.org/ssh/v1/chapter-4.html
      #+++
      
      
      def connect
        check_keys
        machine = find_current_machine
        if @argv.cmd
          cmd = @argv.cmd.is_a?(Array) ? @argv.cmd.join(' ') : @argv.cmd
        else
          cmd = false
        end
        
        ret = ssh_command(machine[:dns_name], keypairpath, @global.user, cmd, @option.print)
        puts ret if ret  # ssh command returns false with "ssh_exchange_identification: Connection closed by remote host"
        
      end
      
      def copy_valid?
        check_keys
        raise "No path specified (rudy copy FROM-PATH [FROM-PATH ...] TO-PATH)" unless argv.size >= 2
        true
      end
      
      # +paths+ an array of paths to copy. The last element is the "to" path. 
      def copy
        machine = find_current_machine

        paths = @argv
        dest_path = paths.pop
        
        if @option.print
          scp_command machine[:dns_name], keypairpath, @global.user, paths, dest_path, @option.remote, false, @option.print
          return
        end
        
        @option.remote = true if @alias == 'download'
        @option.remote = false if @alias == 'upload'
        
        if @alias == 'scp' || @alias == 'copy'
          @alias = 'download' if @option.remote
          @alias = 'upload' unless @option.remote
        end
        
        scp do |scp|
          transfers = paths.collect { |path| 
            scp.send(@alias, path, dest_path) do |ch, name, sent, total|
               #TODO: Nice printing in place
                #puts "#{name}: #{sent}/#{total}"
            end
            
          }
          transfers.each { |trans| trans.wait }
        end
      end
      
      

      
    end
  end
end

__END__


