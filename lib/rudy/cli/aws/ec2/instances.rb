
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Instances < Rudy::CLI::Base


    def instances_create
      puts "Instances".bright
      
      # Defaults
      opts = {
        :group => 'default',
        :size => 'm1.small',
        :zone => @@global.zone
      }
      
      radd = Rudy::AWS::EC2::Addresses.new(@@global.accesskey, @@global.secretkey)
      rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      
      if @option.address
        raise "Cannot specify both -a and -n" if @option.newaddress
        raise "#{@argv.ipaddress} is not allocated to you" unless radd.exists?(@option.address)
        raise "#{@argv.ipaddress} is already associated!" if radd.associated?(@option.address)
      end
      
      # These can be sent directly to EC2 class
      [:group, :ami, :size, :keypair, :private].each do |n|
        opts[n] = @option.send(n) if @option.send(n)
      end
      
      puts "Creating #{opts[:itype]} instance in #{@@global.zone}"
      
      unless opts[:keypair]
        puts "You did not specify a keypair. Unless you've prepared a user account".color(:blue)
        puts "on this image (#{opts[:ami]}) you will not be able to log in to it.".color(:blue)
        exit unless Annoy.are_you_sure?(:low)
      end
      
      instances = rmach.list_group(opts[:group], :running)
      
      if instances && instances.size > 0
        puts "There are #{instances.size} running in the #{opts[:group]} group."
        exit unless Annoy.are_you_sure?(:low)
      end
      
      if @option.newaddress
        print "Creating address... "
        address = radd.create
        puts "#{address.ipaddress}"
        @option.address = address.ipaddress
      end
            
      first_instance = true
      rmach.create(opts) do |inst| # Rudy::AWS::EC2::Instance objects
        
        # Assign IP address to only the first instance
        if first_instance && @option.address
          puts "Associating #{@option.address} to #{inst.awsid}"
          radd.associate(@option.address, inst.awsid)
          first_instance = false
        end
        
        puts 
        puts @@global.verbose > 0 ? inst.inspect : inst.to_s
      end

    end


    def instances_destroy
      puts "Instances".bright
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      raise "You must provide a group or instance ID" unless opts[:group] || opts[:id]
      
      rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      instances = rmach.list_group(opts[:group], :running, opts[:id])
      inst_names = instances.collect { |inst| inst.dns_public || inst.awsid}
      inst_ids = instances.collect { |inst| inst.awsid}
      raise "No instances running" if instances.nil? || instances.empty?
      
      instance_count = (instances.size == 1) ? '1 instance' : "#{instances.size} instances"
      
      print "Destroying #{instance_count} (#{inst_names.join(', ')}) "
      print "in #{opts[:group]}" if opts[:group]
      puts
      exit unless Annoy.are_you_sure?(:medium)
      
      execute_action("Destroy Failed") { 
        rmach.destroy(inst_ids)
      }
      
    end
    
    def status
      puts "Instances".bright
      opts = {}
      
      opts[:group] = @option.group if @option.group
      opts[:state] = @option.state if @option.state

      # A nil value forces the @ec2.instances.list to return all instances
      if @option.all
        opts[:state] = :any
        opts[:group] = :any
      end

      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
    
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], opts[:state], opts[:id]) do |inst|
        puts
        puts @@global.verbose > 0 ? inst.inspect : inst.to_s
      end
      puts "No instances running" if !lt || lt.empty?
    end
    alias :instances :status

    def ssh
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      @option.user ||= Rudy.sysinfo.user
      
      if @argv.first
        command, command_args = [@argv.first].flatten.join(' ')
        exit unless Annoy.are_you_sure?(:medium) if @option.user == "root"
      end
      
      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end
      
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], opts[:state], opts[:id]) do |inst|
        puts "Connecting to: #{inst.awsid.bright} as #{@option.user.bright} (group: #{inst.groups.join(', ')})", $/
        ssh_opts = {
          #:debug => STDERR,
          :user => @option.user
        }
        ssh_opts[:keys] = @option.pkey if @option.pkey
        
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
          
        command, command_args = :interactive_ssh, @option.print.nil? unless command
        puts rbox.send(command, command_args)
        
      end
    end

    def copy_valid?
      raise "You must supply a source and a target. See rudy-ec2 #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      raise "You cannot download and upload at the same time" if @option.upload && @alias == 'download'
      true
    end
    def copy
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      @option.user ||= Rudy.sysinfo.user
    
      # * +:recursive: recursively transfer directories (default: false)
      # * +:preserve: preserve atimes and ctimes (default: false)
      # * +:task+ one of: :upload (default), :download.
      # * +:paths+ an array of paths to copy. The last element is the "to" path.
      opts[:recursive] = @option.recursive ? true : false
      opts[:preserve] = @option.preserve ? true : false
      
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
    
      opts[:task] = :download if @alias == 'download' || @option.download
      opts[:task] = :upload if @alias == 'upload'
      opts[:task] ||= :upload
    
      #exit unless @option.print || Annoy.are_you_sure?(:low)

      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end


      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], opts[:state], opts[:id]) do |inst|
        puts "Connecting to: #{inst.awsid.bright} as #{@option.user.bright} (group: #{inst.groups.join(', ')})"


        msg = opts[:task] == :upload ? "Upload to" : "Download from"
        @@logger.puts $/, "#{msg} #{inst.awsid}"

        if @option.print
          Rudy::Utils.scp_command inst.dns_public, @option.pkey, @option.user, opts[:paths], opts[:dest], (opts[:task] == :download), false, @option.print
          return
        end

        scp_opts = {
          :recursive => opts[:recursive],
          :preserve => opts[:preserve],
          :chunk_size => 16384
        }

        Rudy::Huxtable.scp(opts[:task], inst.dns_public, @option.user, @option.pkey, opts[:paths], opts[:dest], scp_opts)
        puts 
      end

    end

    def consoles_valid?
    
      @rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
    end
  
    def consoles
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      unless @rmach.any?
        puts "No instances running"
        return
      end
      
      raise "You must provide a group or instance ID" unless opts[:group] || opts[:id]
      
      console = @rmach.console(opts[:id])
    
      if console
        puts Base64.decode64(console)
      else
        puts "Console output is not available"
      end
    
    end
  
  
  end

end; end
end; end



