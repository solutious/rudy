
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Groups < Rudy::CLI::Base
    
    def groups
      puts "Security Groups".bright
      opts = {}
      name = @option.all ? nil : @argv.name
      rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      rgroups.list(name).each do |grp|
        puts '-'*60
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
      puts "Destroying Machine Group".bright
      puts "Destroying group: #{@argv.name}"
      exit unless Annoy.are_you_sure?(:medium)
      @rgroups = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey)
      ret = @rgroups.destroy(@argv.name)
      puts ret ? "Success" : "Failed"
    end
    
    def create_groups
      puts "Creating Machine Group".bright
      opts = check_options
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::Groups.new
      rudy.create(@argv.name, nil, opts)
      rudy.list(@argv.name)
    end
    
    def revoke_groups
      puts "Revoke Machine Group Rule".bright
      opts = check_options
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::Groups.new
      rudy.revoke(@argv.name, opts)
      rudy.list(@argv.name)
    end
    
    def authorize_groups
      puts "Authorize Machine Group Rule".bright
      opts = check_options
      exit unless Annoy.are_you_sure?(:medium)
      rudy = Rudy::Groups.new
      rudy.authorize(opts)
      rudy.list(opts)
    end

    
  private
    
    def check_options
      opts = {}
      [:addresses, :protocols, :owner, :group, :ports].each do |opt|
        opts[opt] = @option.send(opt) if @option.respond_to?(opt)
      end
      opts[:ports].collect! { |port| port.split(/:/) } if opts[:ports]
      opts
    end
    
  end


end; end
end; end
