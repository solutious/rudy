

module Rudy
  module CLI
    class Machines < Rudy::CLI::CommandBase
      
      def machines
        mlist = get_machines
        print_stobjects mlist
      end
      
      def machines_console
        mlist = get_machines
        mlist.each do |machine|
          li machine_separator(machine.name, machine.instid)
          li machine.get_console
        end
      end
      
      def machines_password
        mlist = get_machines
        mlist.each do |machine|
          li machine_separator(machine.name, machine.instid)
          li "Password for %s: %s" % [machine.dns_public, machine.get_password]
        end
        Rudy::Routines::Handlers::Group.authorize rescue nil
      end
      
      def machines_wash
        mlist = get_machines
        dirt = mlist.select { |m| !m.instance_running? }
        
        if dirt.empty?
          li "Nothing to wash in #{current_machine_group}"
          return
        end
        
        li "The following machine metadata will be deleted:".bright
        li dirt.collect {|m| m.name.bright }
        execute_check(:medium)
        
        dirt.each do |m|
          m.destroy
        end
        
      end
      
      def associate_machines_valid?
        @mlist = get_machines
        @alist = Rudy::AWS::EC2::Addresses.list || []
        @alist_used    = @alist.select { |a|  a.associated? }
        @alist_unused  = @alist.select { |a| !a.associated? }
        @alist_unused.collect! { |a| a.ipaddress }
        @alist_instids = @alist_used.collect { |a| a.instid }
        @mlist_static  = @mlist.select do |m| 
          @alist_instids.member?(m.instid)
        end
        
        unless @@global.force
          unless @mlist_static.empty?
            msg = "Some machines already have static IP addresses: #{$/}"
            msg << @mlist_static.collect { |m| "#{m.name}: #{m.dns_public}" }.join($/)
            raise Rudy::Error, msg 
          end
        
          if !@argv.empty? && @mlist.size > @argv.size
            msg = "You supplied #{@argv.size} addresses for #{@mlist.size} "
            msg << "machines. Try: rudy --force machines -S #{@argv.join(' ')}"
            raise Rudy::Error, msg
          end
        
          if @alist_unused.size > 0 && @alist_unused.size < @mlist.size
            msg = "There are only #{@alist_unused.size} available addresses for "
            msg << "#{@mlist.size} machines. Try: rudy --force machines -S #{@argv.join(' ')}"
            raise Rudy::Error, msg
          end
        end
        
        @argv.each do |address|
          unless Rudy::AWS::EC2::Addresses.exists?(address)
            raise "#{address} is not allocated to you" 
          end
          if Rudy::AWS::EC2::Addresses.associated?(address)
            raise "#{address} is already associated!"
          end
        end
        
        @alist_unused = @argv unless @argv.empty? 
        
        true
      end
      
      def associate_machines 
        
        li "Assigning static IP addresses for:"
        li @mlist.collect { |m| m.name }
        
        execute_check(:medium)
        
        @mlist.each do |m|
          next if @mlist_static.member?(m)
          address = @alist_unused.shift
          address ||= Rudy::AWS::EC2::Addresses.create.ipaddress
          li "Associating #{address} to #{m.name} (#{m.instid})"
          Rudy::AWS::EC2::Addresses.associate(address, m.instid)
          sleep 2
          m.refresh!
        end
        
        @alist = Rudy::AWS::EC2::Addresses.list || []
        @alist_used    = @alist.select { |a|  a.associated? }
        @alist_instids = @alist_used.collect { |a| a.instid }
        @mlist_static  = @mlist.select do |m| 
          @alist_instids.member?(m.instid)
        end
        
        unless @mlist_static.empty?
          @mlist_static.each do |m|
            li "%s: %s" % [m.name, m.dns_public]
          end
        end
      end
      
      
      def disassociate_machines_valid?
        @mlist = get_machines
        @alist = Rudy::AWS::EC2::Addresses.list || []
        @alist_used    = @alist.select { |a|  a.associated? }
        @alist_instids = @alist_used.collect { |a| a.instid }
        @mlist_static  = @mlist.select do |m| 
          @alist_instids.member?(m.instid)
        end
        raise NoMachines, current_group_name if @mlist.empty?
        true
      end
      
      
      def disassociate_machines
        if @mlist_static.empty?
          li "No machines in #{current_group_name} have static IP addresses"
        else
          li "The following machines will be updated:"
          li @mlist_static.collect { |m| m.name }
          li "NOTE: Unassigned IP addresses are not removed from your account"
          execute_check(:medium)
          @mlist_static.each do |m|
            address = Resolv.getaddress m.dns_public
            li "Disassociating #{address} from #{m.name} (#{m.instid})"
            Rudy::AWS::EC2::Addresses.disassociate(address)
          end
        end
      end
      
      def update_machines
        mlist = get_machines
        rset = Rye::Set.new(current_group_name, :parallel => @@global.parallel, :user => current_machine_root)
        rset.add_key user_keypairpath(current_machine_root)
        os = current_machine_os
        mlist.each do |m|
          li "Updating #{m.name}"
          rbox = Rudy::Routines::Handlers::RyeTools.create_box m
          rbox.stash = m
          m.refresh!
          rset.add_boxes rbox
          if m.os.to_s != os.to_s
            li "os: #{os}"
            m.os = os
          end
          m.save :replace
        end
        
        unless os.to_s == 'windows'
          li "Updating hostnames for #{current_group_name}"
          Rudy::Routines::Handlers::Host.set_hostname rset
          li rset.hostname.flatten
        end
        
      end
      
      def available_machines
        mlist = get_machines
        mlist.each do |m|
          print "#{m.name}: "
          m.refresh!
          port = m.windows? ? 3389 : 22
          Rudy::Utils.waiter(2, 60, STDOUT, nil, 0) {
            Rudy::Utils.service_available?(m.dns_public, port)
          }
          available = Rudy::Utils.service_available?(m.dns_public, port)
          li available ? 'up' : 'down'
        end
        
      end
      
      
      def ssh_valid?
        #raise "SSH not supported on Windows" if current_machine_os.to_s == 'windows'
        true
      end
      
      def ssh
        
        
        # TODO: Give this method a good look over
        pkey = current_user_keypairpath
        unless pkey
          li "No private key configured for #{current_machine_user} in #{current_machine_group}"
        end
        
        # Options to be sent to Rye::Box
        rye_opts = { :user => current_machine_user, :keys => [], :debug => nil, :info => STDOUT }
        if File.exists? pkey 
          #raise "Cannot find file #{pkey}" unless File.exists?(pkey)
          if Rudy.sysinfo.os != :windows && File.stat(pkey).mode != 33152
            raise InsecureKeyPermissions, pkey 
          end
          rye_opts[:keys] << pkey 
        end
        
        local_keys = Rye.keys
        rye_opts[:keys] += local_keys if local_keys.is_a?(Array)
        
        li "# SSH OPTS", rye_opts.to_yaml if @@global.verbose > 3
        
        # The user specified a command to run. We won't create an interactive
        # session so we need to prepare the command and its arguments
        if @argv.first
          command, command_args = @argv.shift, @argv || []
          Rudy::Huxtable.ld "COMMAND: #{command} #{command_args.join(' ')}" if @@global.verbose > 1

        # otherwise, we'll open an ssh session or print command
        else
          command, command_args = :interactive_ssh, @option.print.nil?
        end
        
        if command == :interactive_ssh && @global.parallel
          raise "Cannot run interactive sessions in parallel"
        end
        
        checked = false
        lt = get_machines
        
        rset = Rye::Set.new(current_machine_group, :parallel => @global.parallel)
        lt.each do |machine|
          if Rudy::Machine === machine 
            machine.refresh! # make sure we have the latest DNS info 
            rbox = Rye::Box.new(machine.dns_public, rye_opts)
            rbox.nickname = machine.name
            instid = machine.instid
          else
            rbox = Rye::Box.new(machine, rye_opts)
            rbox.nickname = machine
            instid = ''
          end
          
          if command == :interactive_ssh
            # Print header
            if @@global.quiet
              print "You are #{rye_opts[:user].to_s.bright}. " if !checked # only the 1st
            else
              li machine_separator(rbox.nickname, instid)
              li "Connecting #{rye_opts[:user].to_s.bright}@#{rbox.host} "
              li
            end
          else
            unless @global.parallel
              rbox.pre_command_hook do |cmd,user,host,nickname|
                print_command user, nickname, cmd
              end
            end
            rbox.post_command_hook do |ret|
              print_response ret
            end
          end

          # Make sure we want to run this command on all instances
          if !checked && command != :interactive_ssh 
            execute_check(:low) if current_machine_user == "root"
            checked = true
          end
          
          # Open the connection and run the command          
          if command == :interactive_ssh
            rbox.send(command, command_args) 
          else
            rset.add_box rbox
          end
        end
        
        rset.send(command, command_args) unless command == :interactive_ssh
        
      end

      
      private 
      # Returns a formatted string for printing command info
      def print_command(user, host, cmd)
        #return if @@global.parallel
        cmd ||= ""
        cmd, user = cmd.to_s, user.to_s
        prompt = user == "root" ? "#" : "$"
        li ("%s@%s%s %s" % [user, host, prompt, cmd.bright])
      end
      
      
      def print_response(rap)
        # Non zero exit codes raise exceptions so  
        # the erorrs have already been handled. 
        return if rap.exit_status != 0

        if @@global.parallel
          cmd, user = cmd.to_s, user.to_s
          prompt = user == "root" ? "#" : "$"
          li "%s@%s%s %s%s%s" % [rap.box.user, rap.box.nickname, prompt, rap.cmd.bright, $/, rap.stdout.inspect]
          unless rap.stderr.empty?
            le "#{rap.box.nickname}: " << rap.stderr.join("#{rap.box.nickname}: ")
          end
        else
          li '  ' << rap.stdout.join("#{$/}  ") if !rap.stdout.empty?
          colour = rap.exit_status != 0 ? :red : :normal
          unless rap.stderr.empty?
            le ("  STDERR  " << '-'*38).color(colour).bright
            le "  " << rap.stderr.join("#{$/}    ").color(colour)
          end
        end
      end
      
    end
  end
end