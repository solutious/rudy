


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
    
    @@config = Rudy::Config.new
    @@global = Rudy::Global.new
    @@logger = StringIO.new    # BUG: memory-leak for long-running apps
    
    # NOTE: These methods conflict with Drydock::Command classes. It's
    # probably a good idea to not expose these anyway since it can be
    # done via Rudy::Huxtable.update_global etc...
    #def config; @@config; end
    #def global; @@global; end
    #def logger; @@logger; end
    
    def self.update_config(path=nil)
      # nil or otherwise bad paths send to look_and_load are ignored
      @@config.look_and_load(path || nil)
      @@global.apply_config(@@config)
    end
    
    update_config
    
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
    
    def debug?; @@debug == true; end
    
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
    
    def user_keypairname(user)
      kp = user_keypairpath(user)
      return unless kp
      KeyPairs.path_to_name(kp)
    end
    
    def user_keypairpath(name)
      raise "No user provided" unless name
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      #Caesars.enable_debug
      kp = @@config.machines.find_deferred(zon, env, rol, [:users, name, :keypair])
      kp ||= @@config.machines.find_deferred(env, rol, [:users, name, :keypair])
      kp ||= @@config.machines.find_deferred(rol, [:users, name, :keypair])
      
      # EC2 Keypairs that were created are intended for starting the machine instances. 
      # These are used as the root SSH keys. If we can find a user defined key, we'll 
      # check the config path for a generated one. 
      if !kp && name.to_s == 'root'
        path = File.join(self.config_dirname, "key-#{current_machine_group}")
        kp = path if File.exists?(path)
      end
      
      kp &&= File.expand_path(kp)
      kp
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
    def current_machine_hostname(group=nil)
      group ||= machine_group
      find_machine(group)[:dns_name]
    end
    
    def current_machine_group
      [@@global.environment, @@global.role].join(Rudy::DELIM)
    end
    
    def current_machine_count
      fetch_machine_param(:positions)
    end
    
    def current_machine_image
      fetch_machine_param(:ami)
      #zon, env, rol = @@global.zone, @@global.environment, @@global.role
      #ami = @@config.machines.find_deferred([zon, env, rol]) || {}
      #ami.merge!(@@config.machines.find_deferred(env, rol, :ami))
      #ami.merge!(@@config.machines.find_deferred(rol, :ami))
      ## I commented this out while cleaning (start of 0.6 branch) . It
      ## seems like a bad idea. I don't want Huxtables throwing exceptions. 
      ##raise Rudy::NoMachineImage, current_machine_group unless ami
      #ami
    end
    
    def current_machine_size
      fetch_machine_param(:size) || 'm1.small'
    end
    
    def current_machine_address
      @@config.machines.find_deferred(@@global.environment, @@global.role, :address)
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
    #     :after: 
    #     - :root: pwd
    #     - :rudy: pwd
    #     :disks: 
    #       :create: 
    #         /rudy/example1: 
    #           :device: /dev/sdr
    #           :size: 2
    #         /rudy/example2: 
    #           :device: /dev/sdm
    #           :size: 1
    #     
    def fetch_routine_config(action)
      raise "No configuration" unless @@config
      raise "No globals" unless @@global
      
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      
      disk_defs = fetch_machine_param(:disks)
      
      routine = @@config.routines.find(@@global.environment, @@global.role, action)

      routine.disks.each_pair do |raction,disks|

        disks.each_pair do |path, props|
          unless disk_defs.has_key?(path)
            @logger.puts "#{path} is not defined. Check your #{action} routines config.".color(:red)
            routine.disks[raction].delete(path) 
            next
          end
          
          routine.disks[raction][path] = disk_defs[path].merge(props) 
          
        end
      end

      routine
    end
    
    def fetch_machine_param(parameter)
      fetch_machine_config[parameter]
    end
    
    def fetch_machine_config
      raise "No configuration" unless @@config
      raise "No globals" unless @@global
      zon, env, rol = @@global.zone, @@global.environment, @@global.role
      hashes = []
      hashes << @@config.machines.find(env, rol)
      hashes << @@config.machines.find(zon, env, rol)
      hashes << @@config.machines.find(zon, [env, rol])
      hashes << @@config.machines.find(zon, env)
      hashes << @@config.machines.find(zon)
      compilation = {}
      hashes.reverse.each do |conf|
        compilation.merge! conf if conf
      end
      compilation
    end
    
    
  end
end
