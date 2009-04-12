

module Rudy
  class Instances
    include Rudy::Huxtable
    include Rudy::AWS
    

    def create(opts={}, &each_inst)
      
      Rudy::Huxtable.update_logger(STDERR)
      
      rgroup = Rudy::Groups.new

      unless rgroup.exists?(opts[:group])
        @@logger.puts "Creating group #{rgroup.name(opts[:group])}"
        rgroup.create opts[:group]
      end
      
      # We don't check via KeyPairs here b/c it's possible for a 
      # non-Rudy keypair to be used. 
      if !opts[:keypair] && !has_keypair?(:root)
        rkey = Rudy::KeyPairs.new
        @@logger.puts "Creating keypair #{rkey.name(opts[:group])}"
        rkey.create opts[:group]
        keypair_name = rkey.name(opts[:group])
      else
        keypair_name = KeyPairs.path_to_name(opts[:keypair] || user_keypairpath(:root))
      end
      
      instance = Rudy::Instance.new
      instance.start(opts)

        @@logger.puts "Instance: #{instance.name} #{instance.awsid}"
        if opts[:address] && index == 0  # We currently only support assigned an address to the first instance
          @@logger.puts "Associating #{opts[:address]} to #{instance.awsid}"
          @@ec2.addresses.associate(instance.awsid, opts[:address])
        end


        begin
          @@logger.puts "Waiting for the instance to startup "        
          Rudy.waiter(2, 120, @@logger, "It's up!", "Not running", 3) { instance.running? }

          # The DNS names are now available so we need to grab that data from AWS
          instance.update_dns

          @@logger.puts $/, "Waiting for the SSH daemon "
          Rudy.waiter(1, 60, @@logger, "It's up!", "Not running", 2) { 
            Rudy::Utils.service_available?(instance.public_dns, 22) 
          }
        rescue Timeout::Error, Interrupt, Exception
          @@logger.puts "Not running yet. Check later: " << "rudy status #{instance.awsid}".color(:blue)
        end
        
      
      instance
    end
    
    def destroy(group=nil, inst_id=[], &each_inst)
      group ||= current_machine_group
      raise "No instances running in #{group}" unless running?(group)
      instances = @@ec2.instances.list_group(group, :running, inst_id)
      instances &&= [instances].flatten
      instances.each { |inst| each_inst.call(inst) } if each_inst
      @@logger.puts $/, "Terminating instances...", $/
      @@ec2.instances.destroy(instances, :skip_check)
    end
    
    # * +state+ instance state (:running, :terminated, :pending, :shutting_down)
    # * +group+ instance group name. The default is the current instance group
    # (as determined by the globals) if none is supplied. A value of :any will 
    # return instances from all groups.
    # * +inst_ids+ An Array of instance IDs (Strings) or Instance objects to 
    # filter the list by. Any instances not in the group will be ignored. 
    # * +each_inst+ a block to execute for every instance in the list. 
    # Returns an Array of Rudy::AWS::EC2::Instance objects
    def list(state=nil, group=nil, inst_ids=[], &each_inst)
      group ||= current_machine_group
      unless group == :any
        instances = @@ec2.instances.list_group(group, state, inst_ids) || []
      else
        instances = @@ec2.instances.list(state, inst_ids) || []
      end
      instances.each { |inst| each_inst.call(inst) } if each_inst
      instances
    end
    
    # See Rudy::Instances#list for arguments.
    # Returns a Hash of Rudy::AWS::EC2::Instance objects (the keys are instance IDs)
    def list_as_hash(state=nil, group=nil, inst_ids=[], &each_inst)
      group ||= current_machine_group
      if group == :any
        instances = @@ec2.instances.list_group_as_hash(group, state, inst_ids) || {}
      else
        instances = @@ec2.instances.list_as_hash(state, inst_ids) || {}
      end
      instances.each_pair { |inst_id,inst| each_inst.call(inst) } if each_inst
      instances
    end
    
    # System console output. 
    #
    # NOTE: Amazon sends the console output as a Base64 encoded string. This method
    # decrypts it before returning it.
    #
    # Returns output for the first instance in the group (if provided) or the first
    # instance ID (if provided)
    def console(group=nil, inst_ids=[])
      group ||= current_machine_group
      instances = @@ec2.instances.list_group(group, :any, inst_ids)
      return if instances.nil?
      output = @@ec2.instances.console_output(instances.first.awsid)
      return unless output
      Base64.decode64(output)
    end
    
    def connect(group=nil, cmd=nil, inst_ids=[], print_only=false)
      group ||= current_machine_group
      instances = @@ec2.instances.list_group(group, :running, inst_ids)
      raise "No instances running" if instances.nil?
      raise "No keypair configured for user #{current_user}" unless current_user_keypairpath
      
      # TODO: If a group is supplied we need to discover the keypair.
      
      instances.each do |inst|
        msg = cmd ? %Q{"#{cmd}" on} : "Connecting to"
        @@logger.puts $/, "#{msg} #{inst.dns_name_public}", $/
        ret = ssh_command(inst.dns_name_public, current_user_keypairpath, @@global.user, cmd, print_only)
        puts ret if ret  # ssh command returns false with "ssh_exchange_identification: Connection closed by remote host"
      end
    end
    
    
    # * +:recursive: recursively transfer directories (default: false)
    # * +:preserve: preserve atimes and ctimes (default: false)
    # * +:task+ one of: :upload (default), :download.
    # * +:paths+ an array of paths to copy. The last element is the "to" path. 
    def copy(group=nil, inst_ids=[], opts={})
      group ||= current_machine_group
      instances = @@ec2.instances.list_group(group, :running, inst_ids)
      raise "No instances running" if instances.nil?
      raise "No keypair configured for user #{current_user}" unless current_user_keypairpath
      raise "You must supply at least one source path" if !opts[:paths] || opts[:paths].empty?
      raise "You must supply a destination path" unless opts[:dest]
       
      
      opts = {
        :task => :upload,
        :recursive => false,
        :preserve => false
      }.merge(opts)
        
        
      instances.each do |inst|
        msg = opts[:task] == :upload ? "Upload to" : "Download from"
        @@logger.puts $/, "#{msg} #{inst.awsid}"
        
        if opts[:print]
          scp_command inst.dns_name_public, current_user_keypairpath, @@global.user, opts[:paths], opts[:dest], (opts[:task] == :download), false, opts[:print]
          return
        end
        
        scp_opts = {
          :recursive => opts[:recursive],
          :preserve => opts[:preserve],
          :chunk_size => 16384
        }
        
        scp(opts[:task], inst.dns_name_public, @@global.user, current_user_keypairpath, opts[:paths], opts[:dest], scp_opts)
        
      end
      
      @@logger.puts
    end
    
    
    # * +group+ instance group name
    def any?(group=nil)
      group ||= current_machine_group
      
      @@ec2.instances.any_group?(group)
    end
    
    def exists?(inst_id)
      @@ec2.instances.exists?(inst_id)
    end
    
    # *NOTE REGARDING THE STATUS METHODS*:
    #
    # We currently return true IF ANY instances are operating
    # in the given state. This is faulty but we can't fix it
    # until we have a way to know how many instances should be
    # running in any given group. 
    #
    # Are *any* instances in the group in the running state? 
    def running?(group=nil)
      !list(:running, group).empty?
    end
    
    # Are *any* instances in the group in the terminated state?
    def terminated?(group=nil)
      !list(:terminated, group).empty?
    end
    
    # Are *any* instances in the group in the shutting-down state?
    def shutting_down?(group=nil)
      !list(:shutting_down, group).empty?
    end
    
    # Are *any* instances in the group in the pending state?
    def pending?(group=nil)
      !list(:pending, group).empty?
    end
    
    # Are *any* instances in the group in the a non-running state?
    def unavailable?(group=nil)
      # We go through @@ec2 so we don't reimplement the "unavailable logic"
      instances = list(:any, group)
      @@ec2.instances.unavailable?(instances)
    end
    

    
    
  private

    def instance_data
      data = {
        # Give the instance an identity
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
  class NoGroup < RuntimeError
    def initialize(group)
      @group = group
    end
    def message
      "Group #{@group} does not exist. See: rudy groups -h"
    end
  end
  
  class NoRootKeyPair < RuntimeError
    def initialize(group)
      @group = group
    end
    def message
      "No root keypair for #{@group}. See: rudy keypairs -h"
    end
  end
  
end