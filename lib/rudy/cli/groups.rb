


module Rudy
  module CLI
    class Groups < Rudy::CLI::Base
      
      def group
        puts "Machine Groups".bright
        opts = {}
        opts[:name] = @argv.name if @argv.name && !@option.all
        opts[:all] = true if @option.all
        rudy = Rudy::Groups.new(:config => @config, :global => @global)
        rudy.list(opts).each do |grp|
          puts '-'*60
          puts grp.to_s
        end
      end
      
      def destroy_group(name=@argv.first)
        puts "Destroying Machine Group".bright
        opts = {}
        opts[:name] = @argv.name if @argv.name
        exit unless Annoy.are_you_sure?(:high)
        rudy = Rudy::Groups.new(:config => @config, :global => @global)
        rudy.destroy(opts)
        puts "Done!"
      end
      
      def create_group
        puts "Creating Machine Group".bright
        opts = check_options
        exit unless Annoy.are_you_sure?(:medium)
        rudy = Rudy::Groups.new(:config => @config, :global => @global)
        rudy.create(opts)
        rudy.list(opts)
      end
      
      def revoke_group
        puts "Revoke Machine Group Permissions".bright
        opts = check_options
        exit unless Annoy.are_you_sure?(:medium)
        rudy = Rudy::Groups.new(:config => @config, :global => @global)
        rudy.revoke(opts)
        rudy.list(opts)
      end
      
      def authorize_group
        puts "Authorize Machine Group Permissions".bright
        opts = check_options
        exit unless Annoy.are_you_sure?(:medium)
        rudy = Rudy::Groups.new(:config => @config, :global => @global)
        rudy.authorize(opts)
        rudy.list(opts)
      end

      
    private
      
      def check_options
        opts = {}
        opts[:name] = @argv.name if @argv.name && !@option.all
        opts[:all] = true if @option.all
        [:addresses, :protocols, :owner, :group, :ports].each do |opt|
          opts[opt] = @option.send(opt) if @option.respond_to?(opt)
        end
        opts[:ports].collect! { |port| port.split(/:/) } if opts[:ports]
        opts
      end
      
    end
  end
end

