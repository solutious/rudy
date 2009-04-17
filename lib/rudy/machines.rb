


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
    
    field :dns_public
    field :dns_private
    field :state
    
    attr_reader :instance
    
    def init
      #@created = 
      @rtype = 'm'
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = find_next_position || '01'
      @state = 'no-instance'
    end
    
    def liner_note
      info = @dns_public && !@dns_public.empty? ? @dns_public : @state
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
      
      opts = {
        :min  => 1,
        :size => current_machine_size,
        :ami => current_machine_image,
        :group => current_group_name,
        :keypair => root_keypairname, 
        :zone => @@global.zone.to_s,
        :address => current_machine_address,
        :machine_data => Machine.generate_machine_data.to_yaml
      }.merge(opts)
      
      @ec2inst.create(opts) do |inst|
        @awsid = inst.awsid
        @created = @starts = Time.now
        @state = inst.state
      end
      
      self.save
      
      self
    end

    
    def Machine.generate_machine_data
      data = {      # Give the machine an identity
        :region => @@global.region.to_s,
        :zone => @@global.zone.to_s,
        :environment => @@global.environment.to_s,
        :role => @@global.role.to_s,
        :position => @@global.position.to_s,
        
        :hosts => { # Add hosts to the /etc/hosts file 
          :dbmaster => "127.0.0.1",
        }
      } 
      data
    end
    
    def running?
      return false if @awsid.nil? || !@awsid.empty?
      @ec2inst.running?(@awsid)
    end
      
  end
  
  
  
  class Machines
    include Rudy::MetaData
    
    def init
      a, s, r = @@global.accesskey, @@global.secretkey, @@global.region
      @rinst = Rudy::AWS::EC2::Instances.new(a, s, r)
      @rgrp = Rudy::AWS::EC2::Groups.new(a, s, r)
      @rkey = Rudy::AWS::EC2::KeyPairs.new(a, s, r)
    end
    
    def create(&each_mach)
      raise MachineGroupAlreadyRunning, current_machine_group if running?
      raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
      unless (1..MAX_INSTANCES).member?(current_machine_count)
        raise "Instance count must be more than 0, less than #{MAX_INSTANCES}"
      end
      
      unless @rgrp.exists?(current_group_name)
        puts "Creating group: #{current_group_name}"
        @rgrp.create(current_group_name)
      end
      
      unless @rkey.exists?(root_keypairname)
        kp_file = File.join(Rudy::CONFIG_DIR, root_keypairname)
        raise PrivateKeyFileExists, kp_file if File.exists?(kp_file)
        puts "Creating keypair: #{root_keypairname}"
        kp = @rkey.create(root_keypairname)
        puts "Saving #{kp_file}"
        Rudy::Utils.write_to_file(kp_file, kp.private_key, 'w', 0600)
      else
        kp_file = root_keypairpath
        # This means we found a keypair in the config but we cannot find the private key file. 
        raise PrivateKeyNotFound, kp_file if kp_file && !File.exists?(kp_file)
      end
      
      current_machine_count.times do  |i|
        machine = Rudy::Machine.new
        puts "Starting %s" % machine.name
        machine.start
      end
      
    end
    
    
    def destroy(&each_mach)
      #raise MachineGroupAlreadyRunning, current_machine_group if running?
      #raise MachineGroupNotDefined, current_machine_group unless known_machine_group?
      
    end
    
    def list(more=[], less=[], &each_mach)
      machines = list_as_hash(&each_mach)
      machines &&= machines.values
      machines
    end
    
    def list_as_hash(more=[], less=[], &each_mach)
      query = to_select([:rtype, 'm'], less)
      list = @sdb.select(query) || {}
      machines = {}
      list.each_pair do |n,m|
        machines[n] = Rudy::Machine.from_hash(m)
      end
      machines.each_pair { |n,mach| each_mach.call(mach) } if each_mach
      machines = nil if machines.empty?
      machines
    end
    
    def get(rname=nil)
      Rudy::Machine.from_hash(@sdb.get(Rudy::DOMAIN, rname)) # Returns nil if empty
    end
    
    
    def running?
      !list.nil?
      # TODO: add logic that checks whether the instances are running.
    end
    

    
  end
  
end