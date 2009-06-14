  


module Rudy
  
  # = Rudy::Huxtable
  #
  # Huxtable gives access to instances for config, global, and logger to any
  # class that includes it.
  #
  #     class Rudy::Hello
  #       include Rudy::Huxtable
  #
  #       def print_config
  #         p @@config.defaults  # {:nocolor => true, ...}
  #         p @@global.verbose   # => 1
  #         p @@logger.class     # => StringIO
  #       end
  #
  #     end
  #
  module Huxtable
    
    @@config = Rudy::Config.new
    @@global = Rudy::Global.new
    @@logger = StringIO.new    # BUG: memory-leak for long-running apps
    
    def self.config; @@config; end
    def self.global; @@global; end
    def self.logger; @@logger; end
    
    def self.update_config(path=nil)
      @@config.verbose = (@@global.verbose > 1)
      # nil and bad paths sent to look_and_load are ignored
      @@config.look_and_load(path || @@global.config)
      @@global.apply_config(@@config)
      # And then update global again b/c some values come from @@config
      update_global  ## TODO: Check if this can be removed
    end

    def self.update_global(ghash={}); @@global.update(ghash); end
    def self.update_logger(logger);   @@logger = logger; end
    
    def self.reset_config; @@config = Rudy::Config.new; end
    def self.reset_global; @@global = Rudy::Global.new; end
    
    def self.create_domain
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      @sdb.create_domain Rudy::DOMAIN
    end
    
    def self.domain_exists?
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      (@sdb.list_domains || []).member? Rudy::DOMAIN
    end
    
    def self.domain
      Rudy::DOMAIN
    end
    
    # Print +msg+ to +@@logger+
    def self.li(msg);  @@logger.puts msg;                end
    # Print +msg+ to +@@logger+ if +Rudy.debug?+ returns true
    def self.ld(msg); @@logger.puts msg if Rudy.debug?; end
    # Print +msg+ to +@@logger+ with "ERROR: " prepended
    def self.le(msg); @@logger.puts "ERROR: #{msg}" end
    
    def li(msg);  Rudy::Huxtable.li msg;  end
    def ld(msg); Rudy::Huxtable.ld msg; end
    
    
    
    def config_dirname
      raise "No config paths defined" unless @@config.is_a?(Rudy::Config) && @@config.paths.is_a?(Array)
      base_dir = File.dirname @@config.paths.first
      raise "Config directory doesn't exist #{base_dir}" unless File.exists?(base_dir)
      base_dir
    end
    
    def has_keypair?(name=nil)
      kp = user_keypairpath(name)
      (!kp.nil? && File.exists?(kp))
    end
    
    # Returns the name of the current keypair for the given user. 
    # If there's a private key path in the config this will return
    # the basename (it's assumed the Amazon KeyPair has the same
    # name as the file). Otherwise this returns the Rudy style
    # name: <tt>key-ZONE-ENV-ROLE-USER</tt>. Or if this the user is 
    # root: <tt>key-ZONE-ENV-ROLE</tt>
    def user_keypairname(user)
      kp = user_keypairpath(user)
      if kp
        kp = Huxtable.keypair_path_to_name(kp)
      else
        n = (user.to_s == 'root') ? '' : "-#{user}"
        "key-%s-%s%s" % [@@global.zone, current_machine_group, n]
      end    
    end
    def root_keypairname
      user_keypairname :root
    end
    
    
    def user_keypairpath(name)
      raise Rudy::Error, "No user provided" unless name
      raise NoConfig unless @@config
      raise NoMachinesConfig unless @@config.machines
      raise NoGlobal unless @@global
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      #Caesars.enable_debug
      path = @@config.machines.find_deferred(zon, env, rol, [:users, name, :keypair])
      path ||= @@config.machines.find_deferred(env, rol, [:users, name, :keypair])
      path ||= @@config.machines.find_deferred(rol, [:users, name, :keypair])
      
      # EC2 Keypairs that were created are intended for starting the machine instances. 
      # These are used as the root SSH keys. If we can find a user defined key, we'll 
      # check the config path for a generated one. 
      if !path && name.to_s == 'root'
        path = File.join(self.config_dirname, "key-#{@@global.zone}-#{current_machine_group}")
      end
      path = File.expand_path(path) if path && File.exists?(path)
      path
    end
    def root_keypairpath
      user_keypairpath :root
    end
    
    def has_root_keypair?
      path = user_keypairpath(:root)
      (!path.nil? && !path.empty?)
    end
    
    def current_user
      @@global.user
    end
    def current_user_keypairpath
      user_keypairpath(current_user)
    end
    
    def current_machine_group
      [@@global.environment, @@global.role].join(Rudy::DELIM)
    end
    
    def current_group_name
      "g-#{current_machine_group}"
    end
    
    def current_machine_count
      fetch_machine_param(:positions) || 1
    end
    
    def current_machine_hostname
      # NOTE: There is an issue with Caesars that a keyword that has been
      # defined as forced_array (or forced_hash, etc...) is like that for
      # all subclasses of Caesars. There is a conflict between "hostname" 
      # in the machines config and routines config. The routines config 
      # parses hostname with forced_array because it's a shell command
      # in Rye::Cmd. Machines config expects just a symbol. The issue
      # is with Caesars so this is a workaround to return a symbol.
      hn = fetch_machine_param(:hostname) || :rudy
      hn = hn.flatten.compact.first if hn.is_a?(Array)
      hn
    end
    
    def current_machine_image
      fetch_machine_param(:ami)
    end
    
    def current_machine_os
      fetch_machine_param(:os) || 'linux'
    end
    
    def current_machine_size
      fetch_machine_param(:size) || 'm1.small'
    end
    
    def current_machine_address(position='01')
      raise NoConfig unless @@config
      raise NoMachinesConfig unless @@config.machines
      raise "Position cannot be nil" if position.nil?
      addresses = [fetch_machine_param(:addresses)].flatten.compact
      addresses[position.to_i-1]
    end
    
    # TODO: fix machine_group to include zone
    def current_machine_name
      [@@global.zone, current_machine_group, @@global.position].join(Rudy::DELIM)
    end

    # +name+ the name of the remote user to use for the remainder of the command
    # (or until switched again). If no name is provided, the user will be revert
    # to whatever it was before the previous switch. 
    # TODO: deprecate
    def switch_user(name=nil)
      if name == nil && @switch_user_previous
        @@global.user = @switch_user_previous
      elsif @@global.user != name
        raise "No root keypair defined for #{name}!" unless has_keypair?(name)
        @@logger.puts "Remote commands will be run as #{name} user"
        @switch_user_previous = @@global.user
        @@global.user = name
      end
    end
    
    def self.keypair_path_to_name(kp)
      return nil unless kp
      name = File.basename kp
      #name.gsub(/key-/, '')   # We keep the key- now
    end
    
    
    # Looks for ENV-ROLE configuration in machines. There must be
    # at least one definition in the config for this to return true
    # That's how Rudy knows the current group is defined. 
    def known_machine_group?
      raise NoConfig unless @@config
      return true if default_machine_group?
      raise NoMachinesConfig unless @@config.machines
      return false if !@@config && !@@global
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      conf = @@config.machines.find_deferred(@@global.region, zon, [env, rol])
      conf ||= @@config.machines.find_deferred(zon, [env, rol])
      !conf.nil?
    end
    
  private 
    
    
    # We grab the appropriate routines config and check the paths
    # against those defined for the matching machine group. 
    # Disks that appear in a routine but not in a machine will be
    # removed and a warning printed. Otherwise, the routines config
    # is merged on top of the machine config and that's what we return.
    #
    # This means that all the disk info is returned so we know what
    # size they are and stuff. 
    # Return a hash:
    #
    #      :after: 
    #      - :root: !ruby/object:Proc {}
    #      - :rudy: !ruby/object:Proc {}
    #      :disks: 
    #        :create: 
    #          /rudy/example1: 
    #            :device: /dev/sdr
    #            :size: 2
    #          /rudy/example2: 
    #            :device: /dev/sdm
    #            :size: 1
    #      
    # NOTE: dashes in +action+ are converted to underscores. We do this
    # because routine names are defined by method names and valid
    # method names don't use dashes. This way, we can use a dash on the
    # command-line which looks nicer (underscore still works of course). 
    def fetch_routine_config(action)
      raise "No action specified" unless action
      raise NoConfig unless @@config
      raise NoRoutinesConfig unless @@config.routines
      raise NoGlobal unless @@global
      
      action = action.to_s.tr('-', '_')
      
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      
      disk_defs = fetch_machine_param(:disks) || {}
      
      # We want to find only one routines config with the name +action+. 
      # This is unlike the routines config where it's okay to merge via
      # precedence. 
      routine = @@config.routines.find_deferred(@@global.environment, @@global.role, action)
      routine ||= @@config.routines.find_deferred([@@global.environment, @@global.role], action)
      routine ||= @@config.routines.find_deferred(@@global.role, action)
      return nil unless routine
      return routine unless routine.has_key?(:disks)
      
      routine.disks.each_pair do |raction,disks|
        unless disks.kind_of?(Hash)
          li "#{raction} is not defined. Check your #{action} routines config.".color(:red)
          next
        end
        disks.each_pair do |path, props|
          unless disk_defs.has_key?(path)
            li "#{path} is not defined. Check your #{action} machines config.".color(:red)
            routine.disks[raction].delete(path) 
            next
          end
          
          routine.disks[raction][path] = disk_defs[path].merge(props) 
          
        end
      end

      routine
    end
    
    # Is +action+ a valid routine for the current machine group?
    def valid_routine?(action)
      !fetch_routine_config(action).nil?
    end
    
    def fetch_machine_param(parameter)
      raise "No parameter specified" unless parameter
      raise NoConfig unless @@config
      return if !@@config.machines && default_machine_group?
      raise NoMachinesConfig if !@@config.machines
      raise NoGlobal unless @@global
      top_level = @@config.machines.find(parameter)
      mc = fetch_machine_config || {}
      mc[parameter] || top_level || nil
    end
    
    # Returns true if this is the default machine environment and role
    def default_machine_group?
      default_env = @@config.defaults.environment || Rudy::DEFAULT_ENVIRONMENT
      default_rol = @@config.defaults.role || Rudy::DEFAULT_ROLE
      @@global.environment == default_env && @@global.role == default_rol
    end
    
    def fetch_machine_config
      raise NoConfig unless @@config
      raise NoMachinesConfig unless @@config.machines
      raise NoGlobal unless @@global
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      hashes = []
      hashes << @@config.machines.find(env, rol)
      hashes << @@config.machines.find(zon, env, rol)
      hashes << @@config.machines.find(zon, [env, rol])
      hashes << @@config.machines.find(zon, env)
      hashes << @@config.machines.find(env)
      hashes << @@config.machines.find(zon)
      compilation = {}
      hashes.reverse.each do |conf|
        compilation.merge! conf if conf
      end
      compilation = nil if compilation.empty?
      compilation
    end
    
    # Returns the appropriate config block from the machines config.
    # Also adds the following unless otherwise specified:
    # :region, :zone, :environment, :role, :position
    def fetch_script_config
      sconf = fetch_machine_param :config
      sconf ||= {}
      extras = {
        :region => @@global.region,
        :zone => @@global.zone,
        :environment => @@global.environment,
        :role => @@global.role,
        :position => @@global.position
      }
      sconf.merge! extras
      sconf
    end
    
    
  end
end

