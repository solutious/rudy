

module Rudy
  module CLI
    class Config < Rudy::CLI::CommandBase
      
      # We force the CLI::Base#print_header to be quiet
      def print_header
        #@@global.quiet = true
        #super
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
      # e.g. if [prod][app][ami] is not available, it will check [prod][ami]
      # and then [ami]. 
      #
      #     # Display all configuration
      #     $ rudy config --all
      #
      #     # Display just machines
      #     $ rudy config --defaults
      #
      def config
        
        # TODO: Re-enable:
        #     # Display the value for a specific machine.
        #     $ rudy -e prod -r db config param-name
        
        if @@config.nil? || @@config.empty?
          return if @@global.quiet
          raise Rudy::NoConfig
        end

        outform = @@global.format == :json ? :to_json : :to_yaml
        
        types = @option.marshal_dump.keys & @@config.keys # Intersections only
        types = @@config.keys if @option.all
        types = [:machines] if types.empty?
          
        if @option.project
          rf = File.join(RUDY_HOME, 'Rudyfile')
          raise "Cannot find: #{rf}" unless File.exists?(rf)
          li File.read(rf)
          
        elsif @option.script
          conf = fetch_script_config
          li conf.to_hash.send(outform) if conf
          
        else
          #li "# ACCOUNTS: [not displayed]" if types.delete(:accounts)
          types.each do |conftype|
            li "# #{conftype.to_s.upcase}"
            next unless @@config[conftype]  # Nothing to output
            if conftype == :accounts
              skey = @@config[conftype][:aws][:secretkey]
              @@config[conftype][:aws][:secretkey] = hide_secret_key(skey)
            end
            
            li @@config[conftype].to_hash.send(outform)
          end
        end
        
      end
      
      def print_global
        # NOTE: This method cannot be called just "global" b/c that conflicts 
        # with the global accessor for Drydock::Command classes. 
        if @@global.nil?
          raise Rudy::NoGlobal
        end
        gtmp = @@global.clone
        gtmp.format = "yaml" if gtmp.format == :s || gtmp.format == :string
        gtmp.secretkey = hide_secret_key(gtmp.secretkey)
        li gtmp.dump(gtmp.format)
      end
      
      private
      def hide_secret_key(skey)
        skey = skey.to_s
        "%s%s%s" % [skey[0], '.'*18, skey[-1]]
      end
      
    end
  end
end
