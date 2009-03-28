

module Rudy
  class Machines
    include Rudy::Huxtable
    
    def destroy(opts={}, &each_inst)
      opts, instances = process_filter_options(opts)
      raise "No machines running" unless instances && !instances.empty?
      
      @logger.puts "Found instances: #{instances.keys.join(", ")}"
      
      if each_inst
        instances.each_pair { |inst_id,inst| each_inst.call(inst) }
      end
      
      begin
        @logger.puts $/, "Terminating instances...", $/
        @ec2.instances.destroy instances.keys
      rescue => ex
        @logger.puts ex.message if debug?
        @logger.puts ex.backtrace if debug?
        raise ex
      end
      
      true
    end
    
    def create(opts={}, &each_inst)
      raise "No root keypair configured" if !opts[:keypair] && !has_keypair?(:root)
      
      # TODO: Handle itype on create
      opts = { :ami => current_machine_image, 
               :group => current_machine_group, 
               :user => current_user,
               :itype => "m1.small",
               :keypair => user_keypairpath(:root), 
               :address => current_machine_address,
               :machine_data => machine_data.to_yaml }.merge(opts)
      
      instances = @ec2.instances.create(opts[:ami], opts[:group], File.basename(opts[:keypair]), opts[:machine_data], @global.zone)
      #instances = [@ec2.instances.get("i-39009850")]
      instances_with_dns = []
      instances.each_with_index do |inst_tmp,index|
        Rudy.bug('hs672h48') && next if inst_tmp.nil?

        @logger.puts "Instance: #{inst_tmp.awsid}"
        if opts[:address] && index == 0  # We currently only support assigned an address to the first machine
          @logger.puts "Associating #{opts[:address]} to #{inst_tmp.awsid}"
          @ec2.addresses.associate(inst_tmp.awsid, opts[:address])
        end

        @logger.puts "Waiting for the instance to startup "        
        begin 
          Rudy.waiter(2, 120, @logger) { !@ec2.instances.pending?(inst_tmp.awsid) }
          raise Exception unless @ec2.instances.running?(inst_tmp.awsid)
          @logger.puts "It's up!"
          Rudy.bell(3)
        rescue Timeout::Error, Interrupt, Exception
          @logger.puts "It's not up yet. Check later: " << "rudy status #{inst_tmp.awsid}".color(:blue)
          next
        end

        # The DNS names are now available so we need to grab that data from AWS
        instance = @ec2.instances.get(inst_tmp.awsid)   

        @logger.puts $/, "Waiting for the SSH daemon "
        begin
          Rudy.waiter(1, 60, @logger) { Rudy::Utils.service_available?(instance.dns_name_public, 22) }
          @logger.puts "It's up!"
          Rudy.bell(2)
        rescue Timeout::Error, Interrupt, Exception
          @logger.puts "SSH isn't up yet. Check later: " << "rudy status #{inst_tmp.awsid}".color(:blue)
          next
        end

        instances_with_dns << instance

      end
      
      return instances_with_dns unless each_inst
      
      instances_with_dns.each { |inst| each_inst.call(inst) }
      instances_with_dns
    end
    
    
    
    def list(opts={}, &each_inst)
      (list_as_hash(opts, &each_inst) || {}).values
    end
    
    def list_as_hash(opts={}, &each_inst)
      opts, instances = process_filter_options(opts)
      raise "No machines running" unless instances && !instances.empty?
      instances.each_pair { |inst_id,inst| each_inst.call(inst) } if each_inst
      instances
    end
    
    # +opts+ See list
    # Returns true if there are machines running
    def running?(opts={})
      ret = false
      begin
        instances = list(opts)
        ret = (instances && !instances.empty?)
      rescue => ex
      end
      ret
    end
    
    def connect(opts={})
      opts, instances = process_filter_options(opts)
      raise "No machines running" unless instances && !instances.empty?
      
      instances.values.each do |inst|
        msg = opts[:cmd] ? %Q{"#{opts[:cmd]}" on} : "Connecting to"
        @logger.puts $/, "#{msg} #{inst.awsid}", $/
        ret = ssh_command(inst.dns_name_public, current_user_keypairpath, @global.user, opts[:cmd], opts[:print])
        puts ret if ret  # ssh command returns false with "ssh_exchange_identification: Connection closed by remote host"
      end
    end
    
    # * +:recursive: recursively transfer directories (default: false)
    # * +:preserve: preserve atimes and ctimes (default: false)
    # * +:task+ one of: :upload (default), :download.
    # * +:paths+ an array of paths to copy. The last element is the "to" path. 
    def copy(opts={})
      opts, instances = process_filter_options(opts)
      raise "No machines running" unless instances && !instances.empty?
      raise "You must supply at least one source path" if !opts[:paths] || opts[:paths].empty?
      raise "You must supply a destination path" unless opts[:dest]
      
      opts = {
        :task => :upload,
        :recursive => false,
        :preserve => false
      }.merge(opts)
        
      instances.values.each do |inst|
        msg = opts[:task] == :upload ? "Upload to" : "Download from"
        @logger.puts $/, "#{msg} #{inst.awsid}".bright
        
        if opts[:print]
          scp_command inst.dns_name_public, current_user_keypairpath, @global.user, opts[:paths], opts[:dest], (opts[:task] == :download), false, opts[:print]
          return
        end
        
        scp_opts = {
          :recursive => opts[:recursive],
          :preserve => opts[:preserve],
          :chunk_size => 16384
        }
        scp(opts[:task], inst.dns_name_public, @global.user, current_user_keypairpath, opts[:paths], opts[:dest], scp_opts)
        
      end
      
      @logger.puts
    end
    
    
  private
    def process_filter_options(opts)
      opts = { :group => current_machine_group, :id => nil, :state => :running }.merge(opts)
      raise "You must supply either a group name or instance ID" unless opts[:group] || opts[:id]
      opts[:id] &&= [opts[:id]].flatten
      instances = opts[:id] ? @ec2.instances.list(opts[:id], opts[:state]) : @ec2.instances.list_by_group(opts[:group], opts[:state])
      [opts, instances]
    end
    def machine_data
      data = {
        # Give the machine an identity
        :zone => @global.zone,
        :environment => @global.environment,
        :role => @global.role,
        :position => @global.position,
        
        # Add hosts to the /etc/hosts file
        :hosts => {
          :dbmaster => "127.0.0.1",
        }
      } 
      data.to_hash
    end
    
    
    
  end
end