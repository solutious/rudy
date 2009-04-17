


module Rudy
  class Machine < Storable 
    include Rudy::MetaData::ObjectBase
  
    field :rtype
    field :awsid

    field :region
    field :zone
    field :environment
    field :role
    field :position
    
    field :created => Time
    field :started => Time
    
    attr_reader :dns_public
    attr_reader :dns_private
    attr_reader :instance
    
    def init
      #@created = 
      @rtype = 'm'
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = find_next_position || '01'
    end
    
    def liner_note
      info = self.running? ? self.dns_public : 'down'
      "%s (%s)" % [self.name.bright, info]
    end
    
    def to_s(with_title=false)
      lines = []
      lines << liner_note
      #if self.running?
      #  k, g = @keyname || 'no-keypair', self.groups.join(', ')
      #  lines << @@sformat % %w{zone size ami keyname groups} if with_title
      #  lines << @@sformat % [@zone, @size, @ami, k, g]
      #end
      lines.join($/)
    end
    
    def inspect
      lines = []
      lines << liner_note
      field_names.each do |key|
        next unless self.respond_to?(key)
        val = self.send(key)
        lines << sprintf(" %22s: %s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      lines.join($/)
    end
      
    def find_next_position
      list = @sdb.select(self.to_select(nil, [:position])) || []
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
    
    
    def update_dns
      return false unless @awsid
      @instance = @ec2inst.get(@awsid) 
      if @instance.is_a?(Rudy::AWS::EC2::Instance)
        @dns_public = @instance.dns_public
        @dns_private = @instance.dns_private
      end
    end
    
    
    def start(opts={})
      raise "#{name} is already running" if running?
      
      #opts = { :ami => current_machine_image, 
      #         :zone => @@global.zone.to_s,
      #         :group => current_machine_group,
      #         :user => current_user,
      #         :size => current_machine_size,
      #         :keypair => KeyPairs.path_to_name(user_keypairpath(:root)), # Must be a root key
      #         :address => current_machine_address,
      #         :machine_data => generate_machine_data.to_yaml }.merge(opts)
      #
      #raise "NoKeyPair" unless opts[:keypair]
      #
      #inst = @@ec2.instances.create(opts)
      #
      #self.awsid = inst.first.awsid
      #save
      #self
    end

    def generate_machine_data
      Machine.generate_machine_data
    end
    
    def Machine.generate_machine_data
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
    
    def running?(doublecheck=false)
      return (!@awsid && !@awsid.empty?) unless doublecheck
      raise "TODO: support doublecheck"
    end
      
  end
  
  
  
  class Machines
    include Rudy::MetaData
    
    def init
      @ec2inst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
    end
    
    def load(rname=nil)
      Rudy::Machine.from_hash(@sdb.get(Rudy::DOMAIN, rname)) # Returns nil if empty
    end
    
    def list
      list_as_hash.values
    end
    
    def list_as_hash
      list = @sdb.select(to_select([:rtype, 'm'])) || []
      machines = {}
      list.each_pair do |n,m|
        machines[n] = Rudy::Machine.from_hash(m)
      end
      machines = nil if machines.empty?
      machines
    end
    
    def running?
      !list.nil?
      # TODO: add logic that checks whether the instances are running.
    end
    

    
  end
  
end