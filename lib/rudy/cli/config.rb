

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
        # if Rudy.in_situ? # TODO: do something intelligent when running on EC2
        
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
          puts File.read(rf)
          
        elsif @option.script
          conf = fetch_script_config
          puts conf.to_hash.send(outform) if conf
          
        else
          puts "# ACCOUNTS: [not displayed]" if types.delete(:accounts)
          types.each do |conftype|
            puts "# #{conftype.to_s.upcase}"
            next unless @@config[conftype]  # Nothing to output
            puts @@config[conftype].to_hash.send(outform)
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
        gtmp.accesskey = gtmp.secretkey = "[not displayed]"
        puts gtmp.dump(gtmp.format)
      end
      
    end
  end
end
