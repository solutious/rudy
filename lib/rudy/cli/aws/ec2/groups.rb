
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Groups < Rudy::CLI::Base
    
    def groups
      puts "Security Groups".bright
      opts = {}
      name = @option.all ? nil : @argv.name
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rgroups.list(name).each do |grp|
        puts 
        puts grp.to_s
      end
    end
    
    def destroy_groups_valid?
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      raise "No group name provided" unless @argv.name
      raise "Group #{@rgroup.name(@argv.name)} does not exist" unless @rgroups.exists?(@argv.name)
      true
    end
    
    def destroy_groups
      puts "Security Group".bright
      puts "Destroying group: #{@argv.name}"
      exit unless Annoy.are_you_sure?(:medium)
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      ret = @rgroups.destroy(@argv.name)
      puts ret ? "Success" : "Failed"
    end
    
    def create_groups
      puts "Security Group".bright
      opts = check_options
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rudy.create(@argv.name, opts[:addresses], opts[:ports], opts[:protocols])
      rudy.list(@argv.name) do |group|
        puts 
        puts group.to_s
      end
    end
    
    def revoke_groups
      puts "Security Group".bright
      opts = check_options
      raise "Must specify group to modify. #{$0} groups -A NAME" unless @argv.name
      puts "This will revoke #{opts[:addresses].join(', ')} access to group: #{@argv.name}"
      puts "on #{opts[:protocols].join(', ')} ports: #{opts[:ports].map { |p| "#{p.join(':')}" }.join(', ')}"
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rudy.revoke(@argv.name, opts[:addresses], opts[:ports], opts[:protocols])
      rudy.list(@argv.name) do |group|
        puts 
        puts group.to_s
      end
    end
    
    def authorize_groups
      puts "Security Group".bright
      opts = check_options
      raise "Must specify group to modify. #{$0} groups -A NAME" unless @argv.name
      puts "This will authorize #{opts[:addresses].join(', ')} to access group: #{@argv.name}"
      puts "on #{opts[:protocols].join(', ')} ports: #{opts[:ports].map { |p| "#{p.join(' to ')}" }.join(', ')}"
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rudy.authorize(@argv.name, opts[:addresses], opts[:ports], opts[:protocols])
      rudy.list(@argv.name) do |group|
        puts 
        puts group.to_s
      end
    end

    
  private
    
    def check_options
      opts = {}
      [:addresses, :protocols, :owner, :group, :ports].each do |opt|
        opts[opt] = @option.send(opt) if @option.respond_to?(opt)
      end
      opts[:ports].collect! { |port| port.split(/[:-]/) } if opts[:ports]
      opts[:ports] ||= [[22,22],[80,80],[443,443]]
      opts[:addresses] ||= [Rudy::Utils::external_ip_address]
      opts[:protocols] ||= [:tcp]
      opts
    end
    
  end


end; end
end; end
