

module Rudy
  class Machines
    include Rudy::Huxtable
      
    def initialize(opts={})
      super(opts) # opts include config and globals
      @script_runner = Rudy::Routines::ScriptRunner.new(opts)
      @disk_handler = Rudy::Routines::DiskHandler.new(opts)
      @rdisks = Rudy::Disks.new(opts)
    end

    def startup(opts={})
      opts = { :ami => current_machine_image, 
               :group => current_machine_group, 
               :user => current_user, 
               :keypair => user_keypairpath(:root), 
               :address => current_machine_address,
               :machine_data => machine_data.to_yaml }.merge(opts)
      switch_user(:root)
      @logger.puts "using AMI: #{opts[:ami]}"

      routine = fetch_routine(:startup) 

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
          Rudy.waiter(2, 120) { !@ec2.instances.pending?(inst_tmp.awsid) }
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
          Rudy.waiter(2, 60) { Rudy::Utils.service_available?(instance.dns_name_public, 22) }
          @logger.puts "It's up!"
          Rudy.bell(2)
        rescue Timeout::Error, Interrupt
          @logger.puts "SSH isn't up yet. Check later: " << "rudy status #{inst_tmp.awsid}".color(:blue)
          next
        end
        
        
        
        routine.disks.each_pair do |action,disks|
          
          unless @rdisks.respond_to?(action)
            @logger.puts("Skipping unknown action: #{action}").color(:blue)
            next
          end
          
          disks.each_pair do |path,props|
            props[:path] = path
            puts path
            begin
              @rdisks.send(action, instance, props)
            rescue => ex
              @logger.puts "Continuing..."
            end
          end
        end
        
        instances_with_dns << instance
        
        
        
      end
      
      instances_with_dns
    end
    
    
    def shutdown(opts={})
      opts, instances = process_filter_options(opts)
      
      @logger.puts "Found instances: #{instances.keys.join(", ")}"
      
      routine = fetch_routine(:shutdown)
      
      instances.each_pair do |inst,instance|
        @logger.puts $/, "Shutting down #{inst}".bright, $/
        
        @logger.puts $/, "Running BEFORE scripts...", $/
        #instances.each { |inst| @script_runner.execute(inst, :shutdown, :before) }
      
        @logger.puts $/, "Running DISK routines...", $/
        routine.disks.each_pair do |action,disks|
          
          unless @rdisks.respond_to?(action)
            @logger.puts("Skipping unknown action: #{action}").color(:blue)
            next
          end
          
          disks.each_pair do |path,props|
            props[:path] = path
            begin
              @rdisks.send(action, instance, props)
            rescue => ex
              @logger.puts "Continuing..."
              puts ex.message
              puts ex.backtrace
            end
          end
        end

      
        @logger.puts $/, "Terminating instances...", $/
        @ec2.instances.destroy instance.awsid
      
        @logger.puts "Waiting for #{instance.awsid} to terminate"

        begin 
          Rudy.waiter(2, 30) { @ec2.instances.terminated?(instance.awsid) }
          @logger.puts "It's down!"
        rescue Timeout::Error, Interrupt, Exception
          @logger.puts "It's not down yet. Check later: " << "rudy status #{instance.awsid}".color(:blue)
          next
        end
      
        @logger.puts $/, "Running AFTER scripts...".bright, $/
        #instances.each { |inst| @script_runner.execute(instance, :shutdown, :after) }
      end
    end
    
    def list(opts={}, &block)
      opts, instances = process_filter_options(opts)
      if block
        instances.each do |inst|
          block.call(inst)
        end
      end
      instances
    end
    
    
    
    def status(opts={})
      opts, instances = process_filter_options(opts)
      instances.each_pair do |id, inst|
        puts '-'*60
        puts "Instance: #{id.bright} (AMI: #{inst.ami})"
        puts inst.to_s
      end
    end
    
    
    
    
    def connect(opts={})
      opts, instances = process_filter_options(opts)
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
      raise "No machines running" unless instances && !instances.empty?
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
    # We grab the appropriate routines config and check the paths
    # against those defined for the matching machine group. 
    # Disks that appear in a routine but not the machine will be
    # removed and a warning printed. Otherwise, the routines config
    # is merged on top of the machine config and that's what we return.
    def fetch_routine(action)
      disk_definitions = @config.machines.find_deferred(@global.environment, @global.role, :disks)
      routine = @config.routines.find(@global.environment, @global.role, action)
      routine.disks.each_pair do |raction,disks|
        disks.each_pair do |path, props|
          routine.disks[raction][path] = disk_definitions[path].merge(props) if disk_definitions.has_key?(path)
          unless disk_definitions.has_key?(path)
            @logger.puts "#{path} is not defined. Check your #{action} routines config.".color(:red)
            routine.disks[raction].delete(path) 
          end
        end
      end
      routine
    end
    
    
  end
end