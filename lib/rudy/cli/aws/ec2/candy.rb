
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Candy < Rudy::CLI::CommandBase
    
    def status_valid?
      avail = Rudy::Utils.service_available?('status.aws.amazon.com', 80, 5)
      raise ServiceUnavailable, 'status.aws.amazon.com' unless @@global.offline || avail
      true
    end
    def status
      url = 'http://status.aws.amazon.com/rss/EC2.rss'
      
      if (@@global.region || '').to_s.strip.match(/\Aeu/)
        url = 'http://status.aws.amazon.com/rss/EC2EU.rss'
      end
      
      # TODO: Move to Rudy::AWS
      ec2 = Rudy::Utils::RSSReader.run(url) || {}
      
      # TODO: Create Storable object
      if @@global.format == 'yaml'
        li ec2.to_yaml
      elsif @@global.format == 'json'
        require 'json'
        li ec2.to_json
      else
        li "#{ec2[:title]}"
        li "Updated: #{ec2[:pubdate]}"
        (ec2[:items] || []).each do |i|
          li
          li '%s' % i[:title]
          li '  %s: %s' % [i[:pubdate], i[:description]]
        end
        if ec2.empty? || ec2[:items].empty?
          li "No announcements" 
          return
        end
      end
      
      
      
    end
    
    def ssh_valid?
      if @@global.pkey
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise "Insecure permissions for #{@@global.pkey}" unless (File.stat(@@global.pkey).mode & 600) == 0
      end
      if @option.group
        raise "Cannot supply group and instance ID" if @option.instid
        raise "Group #{@option.group} does not exist" unless Rudy::AWS::EC2::Groups.exists?(@option.group)
      end
      if @option.instid && !Rudy::Utils.is_id?(:instance, @option.instid)
        raise "#{@option.instid} is not an instance ID" 
      end
      true
    end
    def ssh
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all
      opts[:id] = @option.instid if @option.instid
      
      # Options to be sent to Rye::Box
      rye_opts = { :user => @global.user || Rudy.sysinfo.user, :debug => nil, :info => STDOUT  }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        rye_opts[:keys] = @@global.pkey 
      end
      
      
      # The user specified a command to run. We won't create an interactive
      # session so we need to prepare the command and its arguments
      if @argv.first
        command, command_args = @argv.shift, @argv || []
        li "#{command} #{command_args.join(' ')}" if @@global.verbose > 1
      
      # otherwise, we'll open an ssh session or print command
      else
        command, command_args = :interactive_ssh, @option.print.nil?
      end
      
      checked = false
      lt = Rudy::AWS::EC2::Instances.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        # Print header
        if @@global.quiet
          print "You are #{rye_opts[:user].bright}. " if !checked # only the 1st
        else
          print "Connecting #{rye_opts[:user].bright}@#{inst.dns_public} "
          li "(#{inst.awsid}, groups: #{inst.groups.join(', ')})"
        end
        
        # Make sure we want to run this command on all instances
        if !checked && command != :interactive_ssh 
          execute_check(:medium) if rye_opts[:user] == "root"
          checked = true
        end
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, rye_opts)
        ret = rbox.send(command, command_args)
        li ret unless command == :interactive_ssh
      end
    end

    def copy_valid?
      raise "You must supply a source and a target. See rudy-ec2 #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      raise "You cannot download and upload at the same time" if @option.upload && @alias == 'download'
      true
    end
    def copy
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy::Utils.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      # Options to be sent to Net::SSH
      rye_opts = { :user => @global.user || Rudy.sysinfo.user, :debug => nil  }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        rye_opts[:keys] = @@global.pkey 
      end
      
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
    
      opts[:task] = :download if %w(dl download).member?(@alias) || @option.download
      opts[:task] = :upload if %w(ul upload).member?(@alias)
      opts[:task] ||= :upload
      opts[:user] = @global.user || Rudy.sysinfo.user
    
    
      # Options to be sent to Rye::Box
      info = @@global.quiet ? nil : STDERR
      rye_opts = { :user => @global.user || Rudy.sysinfo.user, :info => info }
      if @@global.pkey 
        raise "Cannot find file #{@@global.pkey}" unless File.exists?(@@global.pkey)
        raise InsecureKeyPermissions, @@global.pkey unless File.stat(@@global.pkey).mode == 33152
        rye_opts[:keys] = @@global.pkey 
      end
      

      checked = false
      lt = Rudy::AWS::EC2::Instances.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        if @option.print
          scp_command inst.dns_public, @@global.pkey, opts[:user], opts[:paths], opts[:dest], (opts[:task] == :download), false, @option.print
          next
        end
        
        # Print header
        if @@global.quiet
          print "You are #{rye_opts[:user].bright}. " if !checked # only the 1st
        else
          print "Connecting #{rye_opts[:user].bright}@#{inst.dns_public} "
          li "(#{inst.awsid}, groups: #{inst.groups.join(', ')})"
        end
        
        # Make sure we want to run this command on all instances
        if !checked
          #execute_check(:medium) if opts[:user] == "root"
          checked = true
        end
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, rye_opts)
        rbox.send(opts[:task], opts[:paths], opts[:dest])
      end

    end
    
    
    
    private 
    
    def scp_command(host, keypair, user, paths, to_path, to_local=false, verbose=false, printonly=false)

      paths = [paths] unless paths.is_a?(Array)
      from_paths = ""
      if to_local
        paths.each do |path|
          from_paths << "#{user}@#{host}:#{path} "
        end  
        #li "Copying FROM remote TO this machine", $/

      else
        to_path = "#{user}@#{host}:#{to_path}"
        from_paths = paths.join(' ')
        #li "Copying FROM this machine TO remote", $/
      end


      cmd = "scp -r "
      cmd << "-i #{keypair}" if keypair
      cmd << " #{from_paths} #{to_path}"

      li cmd if verbose
      printonly ? (li cmd) : system(cmd)
    end
    
    
    
  end
  
  
end; end
end; end
