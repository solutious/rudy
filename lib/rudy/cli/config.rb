

module Rudy
  module CLI
    class Config < Rudy::CLI::Base
      
      # We force the CLI::Base#print_header to be quiet
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
        
        
        @option.group ||= [@global.environment, @global.role].join(RUDY_DELIM)
        
        return if @config.empty?
        
        # We need to check whether we're running on a human's computer
        # or within EC2 (we call that running "in-situ"). The userdata
        # available when running in-situ is in a different format.
        if Rudy.in_situ?
          
          
        else
          if @option.all
            puts "# ACCOUNTS: not displayed"
            puts "# MACHINES: "
            y @config.machines.to_hash
            puts "# ROUTINES: "
            y @config.routines.to_hash
          elsif @option.defaults
            y @config.defaults.to_hash
          else
            zon, env, rol = @global.zone, @global.environment, @global.role
            usr, att = @global.user, @argv.name
            val = @config.machines.find_deferred(zon, env, rol, usr, att) || ''
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
