

module Rudy
  
  class Machines
    include Rudy::Huxtable
      
    def initialize(opts={})
      super(opts)
      @script_runner = Rudy::Routines::ScriptRunner.new(opts)
      @disks = Rudy::Routines::DiskHandler.new(opts)
    end
    
    def connect(opts={})
      opts, instances = process_filter_options(opts)
      instances.values.each do |inst|
        @logger.puts $/, "Running command on #{inst.awsid}".att(:bright)
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
        :preservw => false
      }.merge(opts)
        
      instances.values.each do |inst|
        msg = opts[:task] == :upload ? "Upload to" : "Download from"
        @logger.puts $/, "#{msg} #{inst.awsid}".att(:bright)
        
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
    
    
    def shutdown(opts={})
      opts, instances = process_filter_options(opts)
      
      @logger.puts "Found instances: #{instances.keys.join(", ")}"
      
      @logger.puts $/, "Running BEFORE scripts...".att(:bright), $/
      #instances.each { |inst| @script_runner.execute(inst, :shutdown, :before) }
      
      @logger.puts $/, "Running DISK routines...".att(:bright), $/
      #@disk_handler
      
      @logger.puts $/, "Terminating instances...".att(:bright), $/
      @ec2.instances.destroy instances.keys
      
      @logger.puts "Waiting for #{instances.keys.first} to terminate"
      waiter(4, 10) do # This raises an exception if it times out
        !@ec2.instances.running?(instances.keys.first)
      end
      
      @logger.puts $/, "Running AFTER scripts...".att(:bright), $/
      #instances.each { |inst| @script_runner.execute(inst, :shutdown, :after) }
    end
       
    def status(opts={})
      opts, instances = process_filter_options(opts)
      instances.each_pair do |id, inst|
        puts '-'*60
        puts "Instance: #{id.att(:bright)} (AMI: #{inst.ami})"
        puts inst.to_s
      end
    end
    
    def startup(opts={})
      opts = { :ami => current_machine_image, 
               :group => current_machine_group, 
               :user => current_user, 
               :keypair => user_keypairpath(:root), 
               :address => current_machine_address,
               :machine_data => machine_data.to_yaml }.merge(opts)

      @logger.puts "using AMI: #{opts[:ami]}"
      
      # TODO: start multiple, update machine data for each
      instances = @ec2.instances.create(opts[:ami], opts[:group], File.basename(opts[:keypair]), opts[:machine_data], @global.zone)
      
      instances.each_with_index do |inst_tmp,index|
        @logger.puts "Instance: #{inst_tmp.awsid}"
        if opts[:address] && index == 0  # We currently only support assigned an address to the first machine
          @logger.puts "Associating #{opts[:address]} to #{inst_tmp.awsid}"
          @ec2.addresses.associate(inst_tmp.awsid, opts[:address])
        end
        
        @logger.puts "Waiting for the instance to startup "        
        begin 
          waiter(2, 120) { @ec2.instances.running?(inst_tmp.awsid) }
          @logger.puts "It's up!\a\a\a"
        rescue Timeout::Error, Interrupt
          @logger.puts "Check later: rudy status #{instances.keys.join(' ')}"
          next
        end
        
        inst = @ec2.instances.get(inst_tmp.awsid)   # The DNS names are now available
        
        @logger.puts $/, "Waiting for the SSH daemon "
        begin
          waiter(2, 60) { Rudy::Utils.service_available?(inst.dns_name_public, 22) }
          @logger.puts "It's up!\a\a"
        rescue Timeout::Error, Interrupt
          @logger.puts "Check later: rudy status #{instances.keys.join(' ')}"
          next
        end
        
        #execute_disk_routines(inst, :startup)
        #execute_routines(inst, :startup, :after)
      end
      
      status(opts)
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
    
  end
end