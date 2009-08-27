

module Rudy; module CLI; 
module AWS; module EC2;
  class InstanceAndGroupError < Drydock::ArgError
    def message; "You cannot provide a group and an instance ID"; end
  end
  class NoInstanceError < Drydock::ArgError
    def message; "You must provide a group or instance ID"; end
  end
  
  class Instances < Rudy::CLI::CommandBase
    
    def instances_create_valid?
      
      raise "Cannot supply an instance ID" if @option.instid
      
      if @option.group
        unless Rudy::AWS::EC2::Groups.exists?(@option.group)
          raise "Group #{@option.group} does not exist"
        end
      end
      
      true
    end
      
    def instances_create
      
      opts = {                 # Defaults
        :group => 'default',
        :size => 'm1.small',
        :zone => @@global.zone
      }
            
      if @option.address
        raise "Cannot specify both -a and -n" if @option.newaddress
        unless Rudy::AWS::EC2::Addresses.exists?(@option.address)
          raise "#{@option.address} is not allocated to you" 
        end
        if Rudy::AWS::EC2::Addresses.associated?(@option.address)
          raise "#{@option.address} is already associated!" 
        end
      end
      
      # These can be sent directly to EC2 class
      [:group, :ami, :size, :keypair, :private].each do |n|
        opts[n] = @option.send(n) if @option.send(n)
      end
      
      li "Creating #{opts[:size]} instance in #{@@global.zone}"
      
      unless opts[:keypair]
        li "You did not specify a keypair. Unless you've prepared a user account".bright
        li "on this image (#{opts[:ami]}) you will not be able to log in to it.".bright
        exit unless Annoy.proceed?(:low)
      end
      
      instances = Rudy::AWS::EC2::Instances.list_group(opts[:group], :running)
      
      if instances && instances.size > 0
        instance_count = (instances.size == 1) ? 'is 1 instance' : "are #{instances.size} instances"
        li "There #{instance_count} running in the #{opts[:group]} group."
        exit unless Annoy.proceed?(:low)
      end
      
      if @option.newaddress
        print "Creating address... "
        address = Rudy::AWS::EC2::Addresses.create
        li "#{address.ipaddress}"
        @option.address = address.ipaddress
      end
         
      execute_action do
        first_instance = true
        Rudy::AWS::EC2::Instances.create(opts) do |inst| # Rudy::AWS::EC2::Instance objects
        
          # Assign IP address to only the first instance
          if first_instance && @option.address
            li "Associating #{@option.address} to #{inst.awsid}"
            Rudy::AWS::EC2::Addresses.associate(@option.address, inst.awsid)
            first_instance = false
          end
        
          print_stobject(inst)
        end
      end
    end

    def instances_restart_valid?
      raise InstanceAndGroupError.new(nil, @alias) if @option.group && @argv.instid
      raise NoInstanceError.new(nil, @alias) if !@option.group && !@argv.instid
      
      if @option.group
        unless Rudy::AWS::EC2::Groups.exists?(@option.group)
          raise "Group #{@option.group} does not exist"
        end
      end
      
      if @option.private
        raise Drydock::OptsError.new(nil, @alias, "Cannot allocate public IP for private instance") if @option.address || @option.newadress
      end
      
      raise "No instances" unless Rudy::AWS::EC2::Instances.any?
      true
    end
    alias :instances_destroy_valid? :instances_restart_valid?
    
    def instances_destroy
      instances_action :destroy
    end
    
    def instances_restart
      instances_action :restart
    end
    
    def consoles_valid?
      if @@global.pkey
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise "Insecure permissions for #{@@global.pkey}" unless (File.stat(@@global.pkey).mode & 600) == 0
      end
      raise "No instances" unless Rudy::AWS::EC2::Instances.any?
      true
    end
    def consoles
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.instid if @argv.instid
      opts[:id] &&= [opts[:id]].flatten
      
      lt = Rudy::AWS::EC2::Instances.list_group(opts[:group], :any, opts[:id]) do |inst|
        li instance_separator(inst.dns_public || inst.state, inst.awsid)
        console = Rudy::AWS::EC2::Instances.console(inst.awsid)
        output = console ? Base64.decode64(console) : "Unavailable"
        
        # The linux console can include ANSI escape codes for color, 
        # clear screen etc... We strip them out to get rid of the 
        # clear specifically. Otherwise the display is messed!
        output &&= output.noansi 
        
        li output 
        
        if output.match(/<Password>(.+)<\/Password>/m)  # /m, match multiple lines
          li
          if @@global.pkey
            encrtypted_text = ($1 || '').strip
            k = Rye::Key.from_file(@@global.pkey)
            pword = k.decrypt(encrtypted_text)
            answer = "%s: %s" % ['password', pword] 
            Annoy.timed_display(answer, STDERR, 10)
            li
          else
            li "Please supply a private key path to decode the administrator password"
            li "rudy-ec2 -k path/2/privatekey console [-g group] [instance ID]"
          end
        end
        
      end
      
    end
    
    def status
      opts = {}
      
      opts[:group] = @option.group if @option.group
      opts[:state] = @option.state if @option.state

      # A nil value forces the @@ec2.instances.list to return all instances
      if @option.all
        opts[:state] = :any
        opts[:group] = :any
      end

      opts[:id] = @argv.instid if @argv.instid
      opts[:id] &&= [opts[:id]].flatten
      
      ilist = Rudy::AWS::EC2::Instances.list_group(opts[:group], opts[:state], opts[:id])
      ilist.nil? ? li( "No instances running" ) : print_stobjects(ilist)
    end
    alias :instances :status


    private
    
    # * +action+ is one of :destroy, :restart
    def instances_action(action)
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:id] = @argv.instid if @argv.instid
      opts[:id] &&= [opts[:id]].flatten
      
      instances = Rudy::AWS::EC2::Instances.list_group(opts[:group], :running, opts[:id])
      raise "No matching instances running" if instances.nil?
      
      inst_names = instances.collect { |inst| inst.dns_public || inst.awsid }
      inst_ids = instances.collect { |inst| inst.awsid }
      
      instance_count = (instances.size == 1) ? '1 instance' : "#{instances.size} instances"
      
      print "#{action.to_s.capitalize} #{instance_count} (#{inst_names.join(', ')}) "
      print "in #{opts[:group]}" if opts[:group]
      li
      execute_check(:medium)
      
      execute_action("#{action.to_s.capitalize} Failed") { 
        Rudy::AWS::EC2::Instances.send(action, inst_ids)
      }
      status
    end
    
    def instance_separator(name, awsid)
      ('%s %-63s awsid: %s ' % [$/, name, awsid]).att(:reverse)
    end
    
  end

end; end
end; end



