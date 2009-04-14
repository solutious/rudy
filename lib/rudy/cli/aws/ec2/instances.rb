
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
        raise "#{@option.address} is not allocated to you" unless radd.exists?(@option.address)
        raise "#{@option.address} is already associated!" if radd.associated?(@option.address)
      end
      
      # These can be sent directly to EC2 class
      [:group, :ami, :size, :keypair, :private].each do |n|
        opts[n] = @option.send(n) if @option.send(n)
      end
      
      puts "Creating #{opts[:size]} instance in #{@@global.zone}"
      
      unless opts[:keypair]
        puts "You did not specify a keypair. Unless you've prepared a user account".color(:blue)
        puts "on this image (#{opts[:ami]}) you will not be able to log in to it.".color(:blue)
        exit unless Annoy.proceed?(:low)
      end
      
      instances = rmach.list_group(opts[:group], :running)
      
      if instances && instances.size > 0
        instance_count = (instances.size == 1) ? 'is 1 instance' : "are #{instances.size} instances"
        puts "There #{instance_count} running in the #{opts[:group]} group."
        exit unless Annoy.proceed?(:low)
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
      execute_check(:medium)
      
      execute_action("Destroy Failed") { 
        rmach.destroy(inst_ids)
      }
      
    end
    
    def consoles_valid?
      @rinst = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey)
      raise "No instances" unless @rinst.any?
      true
    end
    def consoles
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.awsid if @argv.awsid
      opts[:id] &&= [opts[:id]].flatten
      
      lt = @rinst.list_group(opts[:group], :any, opts[:id]) do |inst|
        puts '-'*50
        puts "Console for: #{inst.liner_note}", $/
        console = @rinst.console(inst.awsid)
        output = console ? Base64.decode64(console) : "Unavailable"
        puts output.noansi # Remove color and clear, etc...
      end
      
    end
    
    def status
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
        puts @@global.verbose > 0 ? inst.inspect : inst.to_s
      end
      puts "No instances running" if !lt || lt.empty?
    end
    alias :instances :status


  end

end; end
end; end



