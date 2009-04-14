
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Groups < Rudy::CLI::Base
    

    
    def create_groups_valid?
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      raise ArgumentError, "No group name provided" unless @argv.name
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
        puts @@global.verbose > 0 ? group.inspect : group.to_s
      end
    end
    
    
    def destroy_groups_valid?
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      raise ArgumentError, "No group name provided" unless @argv.name
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
    
    def revoke_groups_valid?
      if (@option.addresses || @option.ports) && (@option.group || @option.owner)
        raise OptionError, "Cannot mix group and nextwork authorization" 
      end
      raise OptionError, "Must provide -g with -o" if @option.owner && !@option.group
      raise ArgumentError, "Must specify group to modify." unless @argv.name
      @groups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
    end
    
    def revoke_groups
      opts = check_options
      if (@option.group || @option.owner)
        g = "#{opts[:group]}:#{opts[:owner]}"
        puts "Revoke access to #{@argv.name.bright} from #{g.bright}"
      else
        puts "Revoke access to #{@argv.name.bright} from #{opts[:addresses].join(', ').bright}"
        puts "on #{opts[:protocols].join(', ').bright} ports: #{opts[:ports].map { |p| "#{p.join(' to ').bright}" }.join(', ')}"
      end
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      execute_check(:medium)
      execute_action { 
        if (@option.group || @option.owner)
          rgroups.revoke_group(@argv.name, opts[:group], opts[:owner])
        else
          rgroups.revoke(@argv.name, opts[:addresses], opts[:ports], opts[:protocols])
        end
      }
      groups # prints on the modified group b/c of @argv.name
    end
    
    def authorize_groups_valid?
      if (@option.addresses || @option.ports) && (@option.group || @option.owner)
        raise OptionError, "Cannot mix group and network authorization" 
      end
      raise OptionError, "Must provide -g with -o" if @option.owner && !@option.group
      raise ArgumentError, "Must specify group to modify." unless @argv.name
      @groups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
    end
    def authorize_groups
      opts = check_options
      if (@option.group || @option.owner)
        g = [opts[:owner], opts[:group]].join(':')
        puts "Authorize access to #{@argv.name.bright} from #{g.bright}"
      else
        puts "Authorize access to #{@argv.name.bright} from #{opts[:addresses].join(', ').bright}"
        puts "on #{opts[:protocols].join(', ').bright} ports: #{opts[:ports].map { |p| "#{p.join(' to ').bright}" }.join(', ')}"
      end
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      execute_check(:medium)
      execute_action { 
        if (@option.group || @option.owner)
          rgroups.authorize_group(@argv.name, opts[:group], opts[:owner])
        else
          rgroups.authorize(@argv.name, opts[:addresses], opts[:ports], opts[:protocols])
        end
      }
      groups
    end

    def groups
      opts = {}
      name = @option.all ? nil : @argv.name
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rgroups.list(name).each do |group|
        puts @@global.verbose > 0 ? group.inspect : group.to_s
      end
    end
    
  private
    
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
      end
      opts
    end
    
  end


end; end
end; end
