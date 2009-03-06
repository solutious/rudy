

module Rudy
  module Command
    class Config < Rudy::Command::Base
      
      # We force the Command::Base#print_header to be quiet
      def print_header
        @global.quiet = true
        super
      end
      
      
      # Display configuration from the local user data file (~/.rudy/config).
      # This config contains user data which is sent to each EC2 when 
      # it's created. 
      #
      # The primary purpose of this command is to give other apps a way
      # to check various configuration values. (This is mostly useful for
      # debugging and checking configuration on an instance itself).
      #
      # It will return the most specific configuration available. If the 
      # attribute isn'e found it will check each parent for the same attribute. 
      # i.e. if [prod][app][ami] is not available, it will check [prod][ami]
      # and then [ami]. 
      #
      #     # Display the value for a specific machine.
      #     $ rudy -e prod -r db config param-name
      #
      #     # Display all configuration
      #     $ rudy config --all
      #
      def config
        return if @config.nil? 
        puts "Config: #{@config.path}" if @global.verbose > 0
        
        which = @option.defaults ? @global.user : machine_name
        puts "Machine: #{which}" if @global.verbose > 0
        puts "User: #{@global.user}" if @global.verbose > 0
        
        return if @config.empty?
        
        # We need to check whether we're running on a human's computer
        # or within EC2 (we call that running "in-situ"). The userdata
        # available when running in-situ is in a different format.
        if Rudy.in_situ?
          
          
        else
          
          if @option.all
            y @config.machinegroup.to_hash
          else
            env, rol, usr, att = @global.environment, @global.role, @global.user, @argv.name
            val = @config.machinegroup.find_deferred(env, rol, usr, att) || ''
            puts (val.is_a?(String)) ? val : val.to_hash.to_yaml
          end
          
          #name = @argv.first
          #if name && @config.userdata.has_key?(which) 
          #  value = @config.userdata[which][name.to_s]
          #  puts value if value
          #elsif @option.all
          #  puts @config.to_yaml
          #else
          #  value = @config.userdata[which] 
          #  puts value.to_yaml if value
          #end
        end
        
      end
    end
  end
end
