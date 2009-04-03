
require 'rye/box/commands'

module Rye
  
  class Box 
    include Rye::Box::Commands
    
    @@agent_env ||= Hash.new  # ssh-agent env vars
    
      # An instance of Net::SSH::Connection::Session
    attr_reader :ssh
    attr_reader :stdout
    attr_reader :stderr
    
    attr_accessor :host
    attr_accessor :user
    
    def initialize(host, user=nil, opts={})
      user ||= Rye.sysinfo.user
      
      opts = {
        :keypairs => [],
        :stdout => STDOUT,
        :stderr => STDERR,
      }.merge(opts)
      
      @mutex = Mutex.new
      @mutex.synchronize { Box.start_sshagent_environment }   # One thread only
      
      @host = host
      @user = user
      @keypaths = add_keys(opts[:keypaths])
      @stdout = opts[:stdout]
      @stderr = opts[:stderr]
    end
    
    
    at_exit {
      Box.end_sshagent_environment
    }
     
    # Returns an Array of commands available
    def can
      Rye::Box::Commands.instance_methods
    end
    alias :commands :can
       
    # Change the current working directory (sort of). 
    #
    # I haven't been able to wrangle Net::SSH to do my bidding. 
    # "My bidding" in this case, is maintaining an open channel between commands.
    # I'm using Net::SSH::Connection::Session#exec! for all commands
    # which is like a funky helper method that opens a new channel
    # each time it's called. This seems to be okay for one-off 
    # commands but changing the directory only works for the channel
    # it's executed in. The next time exec! is called, there's a
    # new channel which is back in the default (home) directory. 
    #
    # Long story short, the work around is to maintain the current
    # directory locally and send it with each command. 
    # 
    #     rbox.pwd              # => /home/rye ($ pwd )
    #     rbox['/usr/bin'].pwd  # => /usr/bin  ($ cd /usr/bin && pwd)
    #     rbox.pwd              # => /usr/bin  ($ cd /usr/bin && pwd)
    #
    def [](key=nil)
      @current_working_directory = key
      self
    end
    alias :cd :'[]'
    
    # Open an SSH session with +@host+.  
    # Raises a Rye::NoHost exception if +@host+ is not specified.
    def connect
      raise Rye::NoHost unless @host
      disconnect if @ssh 
      @stderr.puts "Opening connection to #{@host}"
      @ssh = Net::SSH.start(@host, @user) 
      @ssh.is_a?(Net::SSH::Connection::Session) && !@ssh.closed?
      self
    end
    
    def disconnect
      return unless @ssh && !@ssh.closed?
      @ssh.loop(0.1) { @ssh.busy? }
      STDERR.puts "Closing connection to #{@ssh.host}"
      @ssh.close
    end
    
    def add_keys(*additional_keys)
      additional_keys = [additional_keys].flatten.compact || []
      Rye::Box.shell("ssh-add", additional_keys) if additional_keys
      Rye::Box.shell("ssh-add") # Add the user's default keys
      self
    end
    
    def keys
      # 2048 76:c9:d7:2f:90:52:ad:75:3d:68:6c:31:21:ca:7b:7f /Users/rye/.ssh/id_rsa (RSA)
      # 2048 7b:a6:bc:51:b1:30:1d:91:9f:73:3a:26:0c:d4:88:0e /Users/rye/.ssh/id_dsa (DSA)
      keystr = Rye::Box.shell("ssh-add", '-l')
      return nil unless keystr
      keystr.split($/).collect do |key|
        key.split(/\s+/)
      end
    end
    
    def Box.prepare_command(*args)
      args &&= [args].flatten.compact
      cmd = args.shift
      cmd = Rye::Box.which(cmd)
      raise CommandNotFound.new(cmd || 'nil') unless cmd
      cmd_clean = Escape.shell_command([cmd, *args]).to_s
      cmd_clean << " 2>&1" # STDERR into STDOUT. Works in DOS also.
    end
    
    # An all ruby implementation of unix "which" command. 
    #
    # * +executable+ the name of the executable
    # 
    # Returns the absolute path if found in PATH otherwise nil.
    def Box.which(executable)
      return unless executable.is_a?(String)
      shortname = File.basename(executable)
      dir = Rye.sysinfo.paths.select do |path|    # dir contains all of the 
        next unless File.exists? path             # occurrences of shortname  
        Dir.new(path).entries.member?(shortname)  # found in the paths. 
      end
      File.join(dir.first, shortname) unless dir.empty? # Return just the first
    end
    
    # Execute a local system command (via the shell, not SSH)
    #  
    # * +cmd+ the executable path (relative or absolute)
    # * +args+ Array of arguments to be sent to the command. Each element
    # is one argument:. i.e. <tt>['-l', 'some/path']</tt>
    #
    # NOTE: shell is a bit paranoid so it escapes every argument. This means
    # you can only use literal values. That means no asterisks too. 
    #
    #
    def Box.shell(cmd, args=[])
      # TODO: allow stdin to be send to cmd
      cmd = Box.prepare_command(cmd, args)
      handle = IO.popen(cmd, "r")
      output = handle.read.chomp
      handle.close
      output
    end
    
    private

      def Box.start_sshagent_environment
        return if @@agent_env["SSH_AGENT_PID"]
        # $ /usr/bin/ssh-agent -s
        # SSH_AUTH_SOCK=/tmp/ssh-9O4ntj5wyw/agent.99415; export SSH_AUTH_SOCK;
        # SSH_AGENT_PID=99416; export SSH_AGENT_PID;
        # echo Agent pid 99416;
        lines = Rye::Box.shell("ssh-agent", '-s') || ''
        lines.split($/).each do |line|
          next unless line.index("echo").nil?
          line = line.slice(0..(line.index(';')-1))
          key, value = line.chomp.split( /=/ )
          @@agent_env[key] = value
        end
        ENV["SSH_AUTH_SOCK"] = @@agent_env["SSH_AUTH_SOCK"]
        ENV["SSH_AGENT_PID"] = @@agent_env["SSH_AGENT_PID"]
        nil
      end

      def Box.end_sshagent_environment
        pid = @@agent_env["SSH_AGENT_PID"]
        Rye::Box.shell("kill", ['-9', pid]) if pid
        nil
      end
      
      # Execute a command over SSH
      #
      # * +args+ is a command name and list of arguments. 
      # The command name is the literal name of the command
      # that will be executed in the remote shell. The arguments
      # will be thoroughly escaped and passed to the command.
      #
      #     rbox = Rye::Box('host').connect
      #     rbox.
      #     $ command 'arg1' 'arg2' etc...
      #
      def command(*args)
        connect if !@ssh || @ssh.closed?
        raise Rye::NotConnected, @host unless @ssh && !@ssh.closed?
        args = args.first.split(/\s+/) if args.size == 1
        cmd, args = args.flatten.compact
        cmd_clean = Escape.shell_command(cmd, *args).to_s
        cmd_clean << " 2>&1" # STDERR into STDOUT. Works in DOS also.
        if @current_working_directory
          cwd = Escape.shell_command('cd', @current_working_directory)
          cmd_clean = "%s && %s" % [cwd, cmd_clean]
        end
        #p cmd_clean
        output = @ssh.exec! cmd_clean
        Rye::Box::Response.new(self, (output || '').split($/))
      end
      
      

  end
end


