

module Rudy
  module CLI
    class Networks < Rudy::CLI::CommandBase
      
      def networks
        name = current_group_name
        Rudy::AWS::EC2::Groups.list(name).each do |group|
          li @@global.verbose > 0 ? group.inspect : group.dump(@@global.format)
        end
      end
      
      def create_networks
        Rudy::Routines::Handlers::Group.create rescue nil
        networks
      end
      
      def destroy_networks
        Rudy::Routines::Handlers::Group.destroy rescue nil
      end
      
      def update_networks
        Rudy::Routines::Handlers::Group.authorize rescue nil
        networks
      end
      
      def local_networks
        ea = Rudy::Utils::external_ip_address || '' 
        ia = Rudy::Utils::internal_ip_address || ''
        if @global.quiet
          li ia unless @option.external && !@option.internal
          li ea unless @option.internal && !@option.external
        else
          li "%10s: %s" % ['Internal', ia] unless @option.external && !@option.internal
          li "%10s: %s" % ['External', ea] unless @option.internal && !@option.external
        end
        @global.quiet = true  # don't print elapsed time
      end
      
      
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

        true
      end
      
      def revoke_networks_valid?; modify_group_valid?; end
      def revoke_networks; modify_group(:revoke); end

      def authorize_networks_valid?; modify_group_valid?; end
      def authorize_networks; modify_group(:authorize); end
      
    private
    
      def modify_group(action)
        group = current_group_name
        
        opts = check_options
        if (@option.group || @option.owner)
          g = [opts[:owner], opts[:group]].join(':')
          li "#{action.to_s.capitalize} access to #{group.bright} from #{g.bright}"
        else
          print "#{action.to_s.capitalize} access to #{group.bright}"
           li " from #{opts[:addresses].join(', ').bright}"
          print "on #{opts[:protocols].join(', ').bright} "
           li "ports: #{opts[:ports].map { |p| "#{p.join(' to ').bright}" }.join(', ')}"
        end
        execute_check(:medium)
        execute_action { 
          if (@option.group || @option.owner)
            Rudy::AWS::EC2::Groups.send("#{action.to_s}_group", group, opts[:group], opts[:owner])
          else
            Rudy::AWS::EC2::Groups.send(action, group, opts[:addresses], opts[:ports], opts[:protocols])
          end
        }
        networks
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
    
    
    
  end
end