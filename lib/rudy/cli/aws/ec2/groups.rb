
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Groups < Rudy::CLI::CommandBase
    

    
    def create_groups_valid?
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise Drydock::ArgError.new('group name', @alias) unless @argv.name
      raise "Group #{@argv.name} alread exists" if @rgroups.exists?(@argv.name)
      true
    end
    def create_groups
      opts = check_options
      puts "Creating #{@argv.name}"
      
      execute_action { 
        @rgroups.create(@argv.name, @option.description, opts[:addresses], opts[:ports], opts[:protocols])
      }
      
      @rgroups.list(@argv.name) do |group|
        puts @@global.verbose > 0 ? group.inspect : group.dump(@@global.format)
      end
    end
    
    
    def destroy_groups_valid?
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise Drydock::ArgError.new('group name', @alias) unless @argv.name
      raise "Group #{@argv.name} does not exist" unless @rgroups.exists?(@argv.name)
      true
    end
    
    def destroy_groups
      puts "Destroying group: #{@argv.name}"
      execute_check(:medium)
      execute_action { @rgroups.destroy(@argv.name) }
      @argv.clear # so groups will print all other groups
      groups
    end
    
    def revoke_groups_valid?; modify_group_valid?; end
    def revoke_groups; modify_group(:revoke); end
    
    def authorize_groups_valid?; modify_group_valid?; end
    def authorize_groups; modify_group(:authorize); end

    def groups
      opts = {}
      name = @option.all ? nil : @argv.name
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
      rgroups.list(name).each do |group|
        puts @@global.verbose > 0 ? group.inspect : group.dump(@@global.format)
      end
    end
    
  private
    
    def modify_group_valid?
      if @option.owner == 'self'
        raise "AWS_ACCOUNT_NUMBER not set" unless @@global.accountnum 
        @option.owner = @@global.accountnum 
      end
      
      if (@option.addresses || @option.ports) && (@option.group || @option.owner)
        raise Drydock::OptError.new('', @alias, "Cannot mix group and network authorization")
      end
      if @option.owner && !@option.group
        raise Drydock::OptError.new('', @alias, "Must provide -g with -o")
      end
      
      raise Drydock::ArgError.new('group name', @alias) unless @argv.name
      @groups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
    end
    
    def modify_group(action)
      opts = check_options
      if (@option.group || @option.owner)
        g = [opts[:owner], opts[:group]].join(':')
        puts "#{action.to_s.capitalize} access to #{@argv.name.bright} from #{g.bright}"
      else
        print "#{action.to_s.capitalize} access to #{@argv.name.bright}"
         puts " from #{opts[:addresses].join(', ').bright}"
        print "on #{opts[:protocols].join(', ').bright} "
         puts "ports: #{opts[:ports].map { |p| "#{p.join(' to ').bright}" }.join(', ')}"
      end
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
      execute_check(:medium)
      execute_action { 
        if (@option.group || @option.owner)
          rgroups.send("#{action.to_s}_group", @argv.name, opts[:group], opts[:owner])
        else
          rgroups.send(action, @argv.name, opts[:addresses], opts[:ports], opts[:protocols])
        end
      }
      groups # prints on the modified group b/c of @argv.name
    end
    
    def check_options
      opts = {}
      [:addresses, :protocols, :owner, :group, :ports].each do |opt|
        opts[opt] = @option.send(opt) if @option.respond_to?(opt)
      end
      unless @option.group || @option.owner
        opts[:ports].collect! { |port| port.split(/[:-]/) } if opts[:ports]
        opts[:ports] ||= [[22,22],[80,80],[443,443]]
        opts[:addresses] ||= [Rudy::Utils::external_ip_address]
        opts[:protocols] ||= [:tcp]
      else
        opts[:owner] ||= @@global.accountnum
      end
      opts
    end
    
  end


end; end
end; end
