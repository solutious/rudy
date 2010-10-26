


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
    extend self
    
    @@config = Rudy::Config.new
    @@global = Rudy::Global.new
    @@logger = StringIO.new    # BUG: memory-leak for long-running apps
    
    def self.config; @@config; end
    def self.global; @@global; end
    def self.logger; @@logger; end
    
    def self.update_config(path=nil)
      @@config.verbose = (@@global.verbose >= 3)   # -vvv
      # nil and bad paths sent to look_and_load are ignored
      @@config.look_and_load(path || @@global.config)
      @@global.apply_config(@@config)
    end

    def self.update_global(ghash); @@global.update(ghash); end
    def self.update_logger(logger)
      return if logger.nil?
      @@logger = logger 
    end
    
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
    
    # Puts +msg+ to +@@logger+
    def self.li(*msg); msg.each { |m| @@logger.puts m } if !@@global.quiet; end
    # Puts +msg+ to +@@logger+ with "ERROR: " prepended
    def self.le(*msg); @@logger.puts "  " << msg.join("#{$/}  "); end
    # Puts +msg+ to +@@logger+ if +Rudy.debug?+ returns true
    def self.ld(*msg)
      return unless Rudy.debug?
      @@logger.puts "D:  " << msg.join("#{$/}D:  ")
    end
    
    def li(*msg); Rudy::Huxtable.li *msg; end
    def le(*msg); Rudy::Huxtable.le *msg; end
    def ld(*msg); Rudy::Huxtable.ld *msg; end
    
    def config_dirname
      raise "No config paths defined" unless @@config.is_a?(Rudy::Config) && @@config.paths.is_a?(Array)
      base_dir = File.dirname @@config.paths.first
      raise "Config directory doesn't exist #{base_dir}" unless File.exists?(base_dir)
      base_dir
    end
    
    def default_root
      (@@config.defaults.root || 'root').to_s
    end
    
    def default_user
      (@@config.defaults.user || current_machine_root).to_s
    end
    
    def current_machine_root
      (fetch_machine_param(:root) || default_root).to_s
    end
    
    def current_machine_user
      (@@global.user || fetch_machine_param(:user) || default_user || Rudy.sysinfo.user).to_s
    end
    
    
    # Returns the name of the current keypair for the given user. 
    # If there's a private key path in the config this will return
    # the basename (it's assumed the Amazon Keypair has the same
    # name as the file). Otherwise this returns the Rudy style
    # name: <tt>key-ZONE-ENV-ROLE-USER</tt>. Or if this the user is 
    # root: <tt>key-ZONE-ENV-ROLE</tt>
    def user_keypairname(user=nil)
      user ||= current_machine_user
      path = defined_keypairpath user
      if path
        Huxtable.keypair_path_to_name(path)
      else
        n = current_user_is_root?(user) ? '' : "-#{user}"
        "key-%s-%s%s" % [@@global.zone, current_machine_group, n]
      end    
    end
    def root_keypairname
      user_keypairname current_machine_root
    end
    def current_user_keypairname
      user_keypairname current_machine_user
    end
    
    def current_user_is_root?(user=nil)
      user ||= current_machine_user
      user.to_s == current_machine_root
    end
    
    def user_keypairpath(name=nil)
      name ||= current_machine_user
      path = defined_keypairpath name
      # If we can't find a user defined key, we'll 
      # check the config path for a generated one.
      if path
        raise "Private key file not found (#{path})" unless File.exists?(path)
        path = File.expand_path(path)
      else
        ssh_key_dir = @@config.defaults.keydir || Rudy::SSH_KEY_DIR
        path = File.join(ssh_key_dir, user_keypairname(name))
      end
      path
    end
    def root_keypairpath
      user_keypairpath current_machine_root
    end
    def current_user_keypairpath
      user_keypairpath current_machine_user
    end
    
    def defined_keypairpath(name=nil)
      name ||= current_machine_user
      raise Rudy::Error, "No user provided" unless name
      ## NOTE: I think it is more appropriate to return nil here
      ## than raise errors. This stuff should be checked already
      ##raise NoConfig unless @@config
      ##raise NoMachinesConfig unless @@config.machines
      ##raise NoGlobal unless @@global
      return unless @@global && @@config && @@config.machines
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      path = @@global.identity
      path ||= @@config.machines.find_deferred(zon, env, rol, [:users, name, :keypair])
      path ||= @@config.machines.find_deferred(env, rol, [:users, name, :keypair])
      path ||= @@config.machines.find_deferred(rol, [:users, name, :keypair])
      path ||= @@config.machines.find_deferred(@@global.region, [:users, name, :keypair])
      path
    end
    
    
    def current_machine_group
      [@@global.environment, @@global.role].join(Rudy::DELIM)
    end
    
    def current_group_name
      "grp-#{@@global.zone}-#{current_machine_group}"
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
      #raise NoConfig unless @@config
      #raise NoMachinesConfig unless @@config.machines
      raise "Position cannot be nil" if position.nil?
      addresses = [fetch_machine_param(:addresses)].flatten.compact
      addresses[position.to_i-1]
    end
    
    # TODO: fix machine_group to include zone
    def current_machine_name
      [@@global.zone, current_machine_group, @@global.position].join(Rudy::DELIM)
    end

    def current_machine_bucket
      @@global.bucket || fetch_machine_param(:bucket) || nil
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
      
      action = action.to_s.tr('-:', '_')
      
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
            li "#{path} is not defined. Check your machines config.".color(:red)
            routine.disks[raction].delete(path) 
            next
          end
          
          routine.disks[raction][path] = disk_defs[path].merge(props) 
          
        end
      end

      routine
    end
    
    def self.generate_rudy_command(name, *args)
      cmd = "rudy "
      cmd << "-C " << @@global.config.join(' -C ') if @@global.config 
      "#{cmd} #{name} " << args.join(' ')
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
      parameter == :positions && @@global.positions || begin  #TODO remove hack
        top_level = @@config.machines.find(parameter)
        mc = fetch_machine_config || {}
        mc[parameter] || top_level || nil
      end
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
      # This is fucked!
      hashes << @@config.machines.find(env, rol)
      hashes << @@config.machines.find(zon, env, rol)
      hashes << @@config.machines.find(zon, [env, rol])
      hashes << @@config.machines.find(zon, env)
      hashes << @@config.machines.find(env)
      hashes << @@config.machines.find(zon)
      hashes << @@config.machines.find(rol)
      hashes << @@config.machines.find(@@global.region)
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

