  


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
    
    field :os
    
    attr_reader :instance
    
      # An ephemeral value which is set after checking whether 
      # the SSH daemon is running. By default this will be set 
      # to false but can be set to true to avoid checking again.
      # See available?
    attr_accessor :available
    
    def init
      #@created = 
      @rtype = 'm'
      @region = @@global.region
      @zone = @@global.zone
      @environment = @@global.environment
      @role = @@global.role
      @position = find_next_position || '01'
      @state = 'no-instance'
      @os = 'unknown'
      @available = false
    end
    
    # See +available+ attribute
    def available?; @available; end
    
    def liner_note
      update #if !dns_public? && @awsid
      info = !@dns_public.nil? && !@dns_public.empty? ? @dns_public : "#{@awsid}:#{@state}"
      "%s  %s" % [self.name.bright, info]
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
      update #if !dns_public? && @awsid
      lines = []
      field_names.each do |key|
        next unless self.respond_to?(key)
        val = self.send(key)
        lines << sprintf("%s=%s", key, (val.is_a?(Array) ? val.join(', ') : val))
      end
      "<Rudy::Machine#%s %s>" % [name, lines.join(' ')]
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
    
    def get_instance
      @ec2inst.get(@awsid) rescue nil
    end
    
    def update
      return false unless @awsid
      @instance = get_instance
      if @instance.is_a?(Rudy::AWS::EC2::Instance)
        @dns_public = @instance.dns_public
        @dns_private = @instance.dns_private
        @state = @instance.state
        save
      elsif @instance.nil?
        @awsid = @dns_public = @dns_private = nil
        @state = 'rogue'
        # Don't save it b/c it's possible the EC2 server is just down. 
      end
    end
    
    def dns_public?
      !@dns_public.nil? && !@dns_public.empty?
    end
    def dns_private?
      !@dns_private.nil? && !@dns_private.empty?
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
        :machine_data => Machine.generate_machine_data.to_yaml
      }.merge(opts)
      
      @os = current_machine_os
      
      @ec2inst.create(opts) do |inst|
        @awsid = inst.awsid
        @created = @starts = Time.now
        @state = inst.state
        # We need to be safe when creating machines because if an exception is
        # raised, instances will have been creating but the calling class won't know. 
        begin
          address = current_machine_address(@position)
          # Assign IP address only if we have one for that position
          if address
            # Make sure the address is associated to the current account
            if @radd.exists?(address)
              puts "Associating #{address} to #{inst.awsid}"
              @radd.associate(address, inst.awsid)
            else
              STDERR.puts "Unknown address: #{address}"
            end
          end
        rescue => ex
          STDERR.puts "Error: #{ex.message}"
          STDERR.puts ex.backtrace if Rudy.debug?
        end
      end
      
      self.save
      
      self
    end
    
    def destroy
      @ec2inst.destroy(@awsid) if running?
      super
    end
    
    def restart
      @ec2inst.restart(@awsid) if running?
    end
    
    def Machine.generate_machine_data
      data = {      # Give the machine an identity
        :region => @@global.region.to_s,
        :zone => @@global.zone.to_s,
        :environment => @@global.environment.to_s,
        :role => @@global.role.to_s,
        :position => (@@global.position || '01').to_s,
        :hosts => { # Add hosts to the /etc/hosts file 
          #:dbmaster => "127.0.0.1",
        }
      } 
      data
    end
    
    def running?
      return false if @awsid.nil? || @awsid.empty?
      @ec2inst.running?(@awsid) rescue nil
    end
      
  end
  
end