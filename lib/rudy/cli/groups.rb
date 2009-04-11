
#
#
module Rudy
  module CLI
    class Groups < Rudy::CLI::Base
      
      def group
        puts "Machine Groups".bright
        opts = {}
        name = @option.all ? nil : @argv.name
        rudy = Rudy::Groups.new
        rudy.list(name).each do |grp|
          puts '-'*60
          puts grp.to_s
        end
      end
      
      def destroy_group_valid?
        @rgroup = Rudy::Groups.new
        raise "Group #{@rgroup.name(@argv.name)} does not exist" unless @rgroup.exists?(@argv.name)
        true
      end
      
      def destroy_group
        puts "Destroying Machine Group".bright
        opts = {}
        puts "Destroying group: #{@rgroup.name(@argv.name)}"
        exit unless Annoy.are_you_sure?(:medium)
        
        @rgroup.destroy(@argv.name)
        puts "Done!"
      end
      
      def create_group
        puts "Creating Machine Group".bright
        opts = check_options
        exit unless Annoy.are_you_sure?(:medium)
        rudy = Rudy::Groups.new
        rudy.create(@argv.name, nil, opts)
        rudy.list(@argv.name)
      end
      
      def revoke_group
        puts "Revoke Machine Group Rule".bright
        opts = check_options
        exit unless Annoy.are_you_sure?(:medium)
        rudy = Rudy::Groups.new
        rudy.revoke(@argv.name, opts)
        rudy.list(@argv.name)
      end
      
      def authorize_group
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
  end
end

