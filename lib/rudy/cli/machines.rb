

module Rudy
  module CLI
    class Machines < Rudy::CLI::CommandBase
      
      
      def machines
        rmach = Rudy::Machines.new
        mlist = rmach.list || []
        if mlist.empty?
          puts "No machines running in #{current_machine_group}" 
          puts "Try: #{$0} startup"
        end
        mlist.each do |m|
          puts @@global.verbose > 0 ? m.inspect : m.dump(@@global.format)
        end
      end
      
      def machines_wash
        rmach = Rudy::Machines.new
        dirt = (rmach.list || []).select { |m| !m.running? }
        if dirt.empty?
          puts "Nothing to wash in #{rmach.current_machine_group}"
          return
        end
        
        puts "The following machine metadata will be deleted:"
        puts dirt.collect {|m| m.name }
        execute_check(:medium)
        
        dirt.each do |m|
          m.destroy
        end
        
      end
      
      
      def ssh
        # TODO: Give this methos a good look over
        pkey = user_keypairpath(@@global.user)
        unless pkey
          puts "No private key configured for #{@@global.user} in #{current_machine_group}"
        end
        
        # Options to be sent to Net::SSH
        ssh_opts = { :user => @@global.user || Rudy.sysinfo.user, :debug => nil  }
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
        rudy = Rudy::Machines.new
        lt = rudy.list do |machine|
          # Print header
          if @@global.quiet
            print "You are #{ssh_opts[:user].to_s.bright}. " if !checked # only the 1st
          else
            print "Connecting #{ssh_opts[:user].to_s.bright}@#{machine.dns_public} "
            puts "#{machine.name} (#{machine.awsid})"
          end

          # Make sure we want to run this command on all instances
          if !checked && command != :interactive_ssh 
            execute_check(:medium) if ssh_opts[:user] == "root"
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