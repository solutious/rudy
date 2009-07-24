

module Rudy
  module CLI
    class Machines < Rudy::CLI::CommandBase
      
      def machines
        # Rudy::Machines.list takes two optional args for adding or 
        # removing metadata attributes to modify the select query. 
        # When all is specified we want to find machines in every
        # environment and role to we remove these attributes from
        # the select. 
        more, less = nil, nil
        less = [:environment, :role] if @option.all
        
        mlist = Rudy::Machines.list(more, less) || []
        if mlist.empty?
          if @option.all
            puts "No machines running"
          else
            puts "No machines running in #{current_machine_group}" 
            puts "Try: rudy machines --all"
          end
        end
        mlist.each do |m|
          puts @@global.verbose > 0 ? m.inspect : m.dump(@@global.format)
        end
      end
      
      def machines_wash
        dirt = (Rudy::Machines.list || []).select { |m| !m.running? }
        if dirt.empty?
          puts "Nothing to wash in #{rmach.current_machine_group}"
          return
        end
        
        puts "The following machine metadata will be deleted:".bright
        puts dirt.collect {|m| m.name.bright }
        execute_check(:medium)
        
        dirt.each do |m|
          m.destroy
        end
        
      end
      
      
      def ssh
        # TODO: Give this methos a good look over
        pkey = user_keypairpath(current_machine_user)
        unless pkey
          puts "No private key configured for #{current_machine_user} in #{current_machine_group}"
        end
        
        # Options to be sent to Net::SSH
        ssh_opts = { :user => current_machine_user, :debug => nil }
        if pkey 
          raise "Cannot find file #{pkey}" unless File.exists?(pkey)
          raise InsecureKeyPermissions, @pkey unless File.stat(pkey).mode == 33152
          ssh_opts[:keys] = pkey 
        end


        # The user specified a command to run. We won't create an interactive
        # session so we need to prepare the command and its arguments
        if @argv.first
          command, command_args = @argv.shift, @argv || []
          puts "#{command} #{command_args.join(' ')}" if @@global.verbose > 1

        # otherwise, we'll open an ssh session or print command
        else
          command, command_args = :interactive_ssh, @option.print.nil?
        end


        checked = false
        lt = Rudy::Machines.list 
        unless lt
          puts "No machines running in #{current_machine_group}"
          exit
        end
        lt.each do |machine|
          machine.update  # make sure we have the latest DNS info
          
          # mount -t ext3 /dev/sdr /rudy/disk1
          
          # Print header
          if @@global.quiet
            print "You are #{ssh_opts[:user].to_s.bright}. " if !checked # only the 1st
          else
            puts machine_separator(machine.name, machine.awsid)
            puts "Connecting #{ssh_opts[:user].to_s.bright}@#{machine.dns_public} "
            puts
          end

          # Make sure we want to run this command on all instances
          if !checked && command != :interactive_ssh 
            execute_check(:low) if ssh_opts[:user] == "root"
            checked = true
          end
          
          # Open the connection and run the command
          rbox = Rye::Box.new(machine.dns_public, ssh_opts)
          ret = rbox.send(command, command_args)
          puts ret unless command == :interactive_ssh
        end
      end


    end
  end
end