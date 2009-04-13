
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Instances < Rudy::CLI::Base


    def instances_create
      puts "Create Instances".bright
      opts = {
        :group => 'default'
      }

      [:group, :ami, :address, :size, :keypair, :private].each do |n|
        opts[n] = @option.send(n) if @option.send(n)
      end
      
      opts[:size] ||= 'm1.small'
      opts[:zone] = @@global.zone
      
      puts "Creating #{opts[:itype]} instance in #{@@global.zone}"
      
      rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      
      unless opts[:keypair]
        puts "You did not specify a keypair. Unless you've prepared a user account".color(:blue)
        puts "on this image (#{opts[:ami]}) you will not be able to log in to it.".color(:blue)
        exit unless Annoy.are_you_sure?(:low)
      end
      
      # TODO: Print number of instances running. If more than 0, use Annoy.are_you_sure?
      rmach.create(opts) do |inst| # Rudy::AWS::EC2::Instance objects
        puts '-'*60
        puts "Instance: #{inst.awsid.bright} (AMI: #{inst.ami})"
        puts inst.to_s
      end

    end


    def instances_destroy
      puts "Destroy Instances".bright
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      raise "You must provide a group or instance ID" unless opts[:group] || opts[:id]
      
      rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      instances = rmach.list_group(opts[:group], :running, opts[:id])
      inst_ids = instances.collect { |inst| inst.awsid }
      raise "No instances running" if instances.nil? || instances.empty?
      print "Destroying #{instances.size} (#{inst_ids.join(', ')}) "
      print "in #{opts[:group]}" if opts[:group]
      puts
      exit unless Annoy.are_you_sure?(:medium)
      rmach.destroy(inst_ids)
      puts "Done!"
    end
    
    def status
      puts "Instance Status".bright
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
        puts '-'*60
        puts "Instance: #{inst.awsid.bright} (AMI: #{inst.ami})"
        puts inst.to_s
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
      
      if @argv.first
        @argv.first = [@argv.first].flatten.join(' ')
        exit unless Annoy.are_you_sure?(:medium) if @option.user == "root"
      end
      
      
      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end
      
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      lt = rudy.list_group(opts[:group], opts[:state], opts[:id]) do |inst|
        puts "Connecting to: #{inst.awsid.bright} (group: #{inst.groups.join(', ')})"
        rbox = Rye::Box.new(inst.dns_name_public, :keys => @option.pkey, :user => @option.user || 'root')
        puts rbox.uname(:a)
      end
    end

    def copy_valid?
      raise "You must supply a source and a target. See rudy #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      true
    end
    def copy
      puts "Rudy Copy".bright
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @option.awsid if @option.awsid
      opts[:id] &&= [opts[:id]].flatten
    
      # Is this more clear?
      @option.recursive && opts[:recursive] = true
      @option.preserve  && opts[:preserve]  = true
      @option.print     && opts[:print]     = true
    
    
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
    
      opts[:task] = :download if @alias == 'download' || @option.download
      opts[:task] = :upload if @alias == 'upload'
      opts[:task] ||= :upload
    
      #exit unless @option.print || Annoy.are_you_sure?(:low)
    
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      rudy.copy(opts[:group], opts[:id], opts)
    end

    def consoles_valid?
    
      @rmach = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
    end
  
    def consoles
      puts "Instance Console".bright
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



