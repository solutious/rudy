require 'tempfile'


module Rudy; module Routines; 
  
  module ScriptHelper
    extend self
    
    @@script_types = [:after, :before, :after_local, :before_local]
    @@script_config_file = "rudy-config.yml"
    
    def before_local(routine, sconf, rbox)
      execute_command(:before_local, routine, sconf, 'localhost', rbox)
    end    
    def after_local(routine, sconf, rbox)
      execute_command(:after_local, routine, sconf, 'localhost', rbox)
    end
  
    def before(routine, sconf, machine, rbox)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:before, routine, sconf, machine.name, rbox)
    end
    def after(routine, sconf, machine, rbox)
      raise "ScriptHelper: Not a Rudy::Machine" unless machine.is_a?(Rudy::Machine)
      execute_command(:after, routine, sconf, machine.name, rbox)
    end
    
  
  private  
    
    # * +timing+ is one of: after, before
    # * +routine+ a single routine hash (startup, shutdown, etc...)
    # * +sconf+ is a config hash from machines config (ignored if nil)
    # * +hostname+ machine hostname that we're working on
    # * +rbox+ a Rye::Box instance for the machine we're working on
    def execute_command(timing, routine, sconf, hostname, rbox)
      raise "ScriptHelper: Not a Rye::Box" unless rbox.is_a?(Rye::Box)
      raise "ScriptHelper: #{timing}?" unless @@script_types.member?(timing)
      
      if sconf && !sconf.empty?
        tf = Tempfile.new(@@script_config_file)
        Rudy::Utils.write_to_file(tf.path, sconf.to_hash.to_yaml, 'w')
      end
      
      # We need to explicitly add the rm command for rbox so we
      # can delete the script config file when we're done. This
      # add the method on for the instance of rbox we are using. 
      def rbox.rm(*args); cmd('rm', args); end
      
      if routine.is_a?(Caesars::Hash) && routine.has_key?(timing)
        puts "Connecting to #{hostname}"
        rbox.connect
        original_user = rbox.user
        scripts = [routine[timing]].flatten
        scripts.each do |script|
          user, command, *args = script.to_a.flatten.compact
          rbox.switch_user user # does nothing if it's the same user
          puts "Creating #{@@script_config_file}"
          rbox.safe = false
          puts rbox.echo("'#{sconf.to_hash.to_yaml}' > #{@@script_config_file}")
          rbox.safe = true
          rbox.chmod(600, @@script_config_file)
          puts %Q{Running (as #{user}): #{rbox.preview_command(command, args)}}
          
          begin
            ret = rbox.send(command, args)
            if ret.exit_code > 0
              puts "  Exit code: #{ret.exit_code}".color(:red)
              puts "  STDERR: #{ret.stderr.join("#{$/}  ")}".color(:red)
              puts "  STDOUT: #{ret.stdout.join("#{$/}  ")}".color(:red)
            else
              puts '  ' << ret.stdout.join("#{$/}  ")
            end
          rescue Rye::CommandNotFound => ex
            puts "  CommandNotFound: #{ex.message}".color(:red)
          end
          
          
          rbox.rm(@@script_config_file)
        end
        rbox.switch_user original_user
      else
        #puts "Nothing to do"
      end
      
      tf.delete # delete local copy of script config
      
    end
  end
  
end;end