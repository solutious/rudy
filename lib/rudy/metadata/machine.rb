


module Rudy
  class Machine < Storable
    include Rudy::Huxtable
    include Rudy::MetaData::ObjectBase
  
    field :rtype
    field :awsid

    field :region
    field :zone
    field :environment
    field :role
    field :position
    
    field :created
    field :started
    
    def init
      #@created = 
      @rtype = 'm'
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = find_next_position || '01'
    end
    
    def find_next_position
      list = @@sdb.select(self.to_select(nil, [:position])) || []
      pos = list.size + 1
      pos.to_s.rjust(2, '0')
    end
    
    def name
      Machine.generate_name(@zone, @environment, @role, @position)
    end

    def Machine.generate_name(zon, env, rol, pos)
      pos = pos.to_s.rjust 2, '0'
      ["m", zon, env, rol, pos].join(Rudy::DELIM)
    end
    
    
    def start 
      # TODO: Handle itype on create
      opts = { :ami => current_machine_image, 
               :zone => @@global.zone.to_s,
               :group => current_machine_group,
               :user => current_user,
               :size => current_machine_size,
               :keypair => KeyPairs.path_to_name(user_keypairpath(:root)), # Must be a root key
               :address => current_machine_address,
               :machine_data => generate_machine_data.to_yaml }
      
      raise "NoKeyPair" unless opts[:keypair]
      
      inst = @@ec2.instances.create(opts)
      
      self.awsid = inst.first.awsid
      save
      self
    end
    
    
    def destroy
      
    end
    
    def generate_machine_data
      data = {
        # Give the machine an identity
        :zone => @@global.zone,
        :environment => @@global.environment,
        :role => @@global.role,
        :position => @@global.position,
        
        # Add hosts to the /etc/hosts file
        :hosts => {
          :dbmaster => "127.0.0.1",
        }
      } 
      data.to_hash
    end
    
    
    
  end
end