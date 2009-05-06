


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
  #         p self.config.defaults
  #       end
  #
  #     end
  #
  module Huxtable
    
    # TODO: investigate @@debug bug. When this is true, Caesars.debug? returns true
    # too. It's possible this is intentional but probably not. 
    @@debug = false
    @@abort = false
    
    @@config = Rudy::Config.new
    @@global = Rudy::Global.new
    @@logger = StringIO.new    # BUG: memory-leak for long-running apps
    
    @@sacred_params = [:accesskey, :secretkey, :cert, :privatekey]
    
    # NOTE: These methods conflict with Drydock::Command classes. It's
    # probably a good idea to not expose these anyway since it can be
    # done via Rudy::Huxtable.update_global etc...
    #def config; @@config; end
    #def global; @@global; end
    #def logger; @@logger; end
    
    def self.update_config(path=nil)
      @@config.verbose = (@@global.verbose > 0)
      # nil and bad paths sent to look_and_load are ignored
      @@config.look_and_load(path || @@global.config)
      @@global.apply_config(@@config)
    end
    
    def self.update_global(ghash={})
      @@global.update(ghash)
    end
    
    def self.update_logger(logger)
      @@logger = logger
    end
    
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
    
    def self.change_zone(v); @@global.zone = v; end
    def self.change_role(v); @@global.role = v; end
    def self.change_region(v); @@global.region = v; end
    def self.change_environment(v); @@global.environment = v; end  
    def self.change_position(v); @@global.position = v; end
    
    def debug?; Rudy::Huxtable.debug?; end
    def Huxtable.debug?; @@debug == true; end
    def check_keys
      raise "No EC2 .pem keys provided" unless has_pem_keys?
      raise "No SSH key provided for #{current_user}!" unless has_keypair?
      raise "No SSH key provided for root!" unless has_keypair?(:root)
    end
      
    def has_pem_keys?
      (@@global.cert       && File.exists?(@@global.cert) && 
       @@global.privatekey && File.exists?(@@global.privatekey))
    end
     
    def has_keys?
      (@@global.accesskey && !@@global.accesskey.empty? && @@global.secretkey && !@@global.secretkey.empty?)
    end
    
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
    
    def group_metadata(env=@@global.environment, role=@@global.role)
      query = "['environment' = '#{env}'] intersection ['role' = '#{role}']"
      @sdb.query_with_attributes(Rudy::DOMAIN, query)
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
    #      - :root: pwd
    #      - :rudy: pwd
    #      :disks: 
    #        :create: 
    #          /rudy/example1: 
    #            :device: /dev/sdr
    #            :size: 2
    #          /rudy/example2: 
    #            :device: /dev/sdm
    #            :size: 1
    #      
    def fetch_routine_config(action)
      raise "No action specified" unless action
      raise NoConfig unless @@config
      raise NoRoutinesConfig unless @@config.routines
      raise NoGlobal unless @@global
      
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

        disks.each_pair do |path, props|
          unless disk_defs.has_key?(path)
            @@logger.puts "#{path} is not defined. Check your #{action} machines config.".color(:red)
            routine.disks[raction].delete(path) 
            next
          end
          
          routine.disks[raction][path] = disk_defs[path].merge(props) 
          
        end
      end

      routine
    end
    
    
    def fetch_machine_param(parameter)
      raise "No parameter specified" unless parameter
      raise NoConfig unless @@config
      raise NoMachinesConfig unless @@config.machines
      raise NoGlobal unless @@global
      top_level = @@config.machines.find(parameter)
      mc = fetch_machine_config
      mc[parameter] || top_level || nil
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

