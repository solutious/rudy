

module Rye
  
  class Box 
    
    include Net::SSH::Prompt
    
    class Response < Array #:nodoc
      attr_reader :box
      def initialize(b, *args)
        @box = b
        super *args
      end
      def to_s
        return self.first if self.size == 1
        super
      end
      
      #---
      # If Box's shell methods return Response objects, then 
      # we can do stuff like this
      # rbox.cp '/etc' | rbox2['/tmp']
      #def |(other)
      #  puts "BOX1", self.join($/)
      #  puts "BOX2", other.join($/)
      #end
      #+++
      
    end

    
    @@agent_env ||= Hash.new
    def initialize(host, user='root', keypaths=[])
      @mutex = Mutex.new
      # only one thread should start the key agent
      @mutex.synchronize { Box.start_sshagent_environment } 
      
      @host = host
      @user = user
      @keypaths = add_keys(keypaths)
      #@bgthread = Thread.new do
      #  loop { @mutex.synchronize { approach } }
      #end
      #@bgthread.join
      
    end
    
    at_exit {
      Box.end_sshagent_environment
    }
    

    def date(*args)
      command('date', args)
    end

    def ls(*args)
      command('ls', args)
    end
    
    def wc(*args)
      command('wc', args)
    end
    
    def [](key)

    end
    
    def disconnect
      return unless @ssh
      @ssh.loop(0.1) { @ssh.busy? }
      @ssh.close
    end
    
    def connect
      if @ssh
        STDERR.puts "Closing previous connection"
        disconnect
      end
      
      @ssh = Net::SSH.start(@host, @user) 
    end
    
    def command(*args)
      args = args.first.split(/\s+/) if args.size == 1
      args = args.flatten.compact
      output = nil
      cmd = Box.prepare_command(args)
      output = @ssh.exec! cmd
      Rye::Box::Response.new(self, (output || '').split($/))
    end
    
    def add_keys(*additional_keys)
      additional_keys = [additional_keys].flatten.compact || []
      Rye::Box.shell("ssh-add", additional_keys) if additional_keys
      Rye::Box.shell("ssh-add") # Add the user's default keys
      additional_keys
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
      
      
      # Execute a system command. 
      #  
      # * +cmd+ the executable path (relative or absolute)
      # * +args+ Array of arguments to be sent to the command. Each element
      # is one argument:. i.e. <tt>['-l', 'some/path']</tt>
      # * +stdin+ not implemented
      #
      # NOTE: shell is a bit paranoid so it escapes every argument. This means
      # you can only use literal values. 
      #
      # TODO: allow stdin to be send to cmd
      #
      def Box.shell(cmd, args=[], stdin=nil)
        cmd = Box.prepare_command(cmd, args)
        handle = IO.popen(cmd, "r")
        output = handle.read.chomp
        handle.close
        output
      end
      
      

  end
end

__END__
# Net:SSH makes me cry on the inside:


def request_pty_if_necessary(channel, with_pty = :pty)
   if with_pty
     channel.request_pty do |ch, success|
       yield ch, success
     end
   else
     yield channel, true
   end
 end


 # Force the command to stop processing, by closing all open channels
 # associated with this command.
 def stop!
   @channels.each do |ch|
     ch.close unless ch[:closed]
   end
 end

 def replace_placeholders(command, channel)
   command.gsub(/\$CAPISTRANO:HOST\$/, channel[:host])
 end


 def open_channels(sessions, cmd='date', with_shell=:shell)
   sessions.map do |session|
       session.open_channel do |channel|

         request_pty_if_necessary(channel) do |ch, success|
           if success
             puts "executing command", cmd
             
             if with_shell == false
               shell = nil
             else
               shell = "sh -c"
               cmd = cmd.gsub(/[$\\`"]/) { |m| "\\#{m}" }
               cmd = "\"#{cmd}\""
             end

             command_line = [environment, shell, cmd].compact.join(" ")
             ch[:command] = command_line

             ch.exec(command_line)
             #ch.send_data(options[:data]) if options[:data]
           else
             # just log it, don't actually raise an exception, since the
             # process method will see that the status is not zero and will
             # raise an exception then.
             puts "could not open channel", cmd
             ch.close
           end
         end

         channel.on_data do |ch, data|
           puts data
         end

         channel.on_extended_data do |ch, type, data|
           puts data
         end

         channel.on_request("exit-status") do |ch, data|
           puts data.read_long
         end

         channel.on_close do |ch|
           ch[:closed] = true
         end
       end
     
   end.flatten
 end


 # prepare a space-separated sequence of variables assignments
 # intended to be prepended to a command, so the shell sets
 # the environment before running the command.
 # i.e.: options[:env] = {'PATH' => '/opt/ruby/bin:$PATH',
 #                        'TEST' => '( "quoted" )'}
 # environment returns:
 # "env TEST=(\ \"quoted\"\ ) PATH=/opt/ruby/bin:$PATH"
 def environment
   #return if options[:env].nil? || options[:env].empty?
   #@environment ||= if String === options[:env]
   #    "env #{options[:env]}"
   #  else
   #    options[:env].inject("env") do |string, (name, value)|
   #      value = value.to_s.gsub(/[ "]/) { |m| "\\#{m}" }
   #      string << " #{name}=#{value}"
   #    end
   #  end
 end

 def process_iteration(sessions, wait=nil, &block)

   ensure_each_session(sessions) { |session| session.preprocess }

   return false if block && !block.call(self)

   readers = sessions.map { |session| session.listeners.keys }.flatten.reject { |io| io.closed? }
   writers = readers.select { |io| io.respond_to?(:pending_write?) && io.pending_write? }

   if readers.any? || writers.any?
     readers, writers, = IO.select(readers, writers, nil, wait)
   end

   if readers
     ensure_each_session(sessions) do |session|
       ios = session.listeners.keys
       session.postprocess(ios & readers, ios & writers)
     end
   end

   true
 end

 def ensure_each_session(sessions)
   errors = []

   sessions.each do |session|
     begin
       yield session
     rescue Exception => error
       raise error
     end
   end

   sessions
 end

 def observer_struct
 	@observer_struct ||= Struct.new(:channel, :stdout, :stderr, :exit_status, :exit_signal)
 end

 def observe_channel(ch, ops={})
 	observer = observer_struct.new(ch, '', '', 0, nil)
 	is_puts = !!ops[:puts]

 	#	stdout
 	ch.on_data do |ch, data|
 		$stdout.print data if is_puts
 		observer.stdout << data
 	end
 	# only handle stderr
 	ch.on_extended_data do |ch, type, data|
 		next unless [1, :stderr].include? type
 		$stderr.print data if is_puts
 		observer.stderr << data
 	end

 	ch.on_request("exit-status") do |ch, data|
 		observer.exit_status = data.read_long
 	end
 	ch.on_request("exit-signal") do |ch, data|
 		observer.exit_signal = data.read_long
 	end

 	observer
 end

 def open_channel(ssh, ops={}, &block)
 	ch = if block_given?
 		ssh.open_channel &block
 	else
 		ssh.open_channel
 	end

 	#	somebody's watching you
 	self.observe_channel ch, ops
 end
 
def connect2
  # from: http://blog.cantremember.com/remote-scripting-for-aws/
  Net::SSH.start(@host, @user, :forward_agent => true, :verbose => :warn) do |ssh|
    ssh.exec! "touch POOP"
    
    open_channel(ssh, {}) do |channel|
      channel.request_pty do |ch, success|
      	raise "could not start a pseudo-tty" unless success

      	#	full EC2 environment
      	###ch.env 'key', 'value'
      	###...

      	ch.exec 'sudo echo Hello 1337' do |ch, success|
      		raise "could not exec against a pseudo-tty" unless success
      	end
      	
      	interrupted = false
      	trap('INT') { interrupted = true }
      	ssh.loop(0.1) {
      		not interrupted
      	}
        
        
      end
    end
  end
end

def forwarding
  ports = [10000]
  offset = 1
  Net::SSH.start(@host, @user, :forward_agent => true, :verbose => :warn) do |ssh|
  	ports.each do |port|
  	  puts "%s %s %s" % [port + offset, 'localhost', port]
  		ssh.forward.local port + offset, 'localhost', port
  	end

  	# loop, with an event loop every 0.1s, until Ctrl-C is pressed
  	puts "[Ctrl-C] to terminate..."
  	interrupted = false
  	trap('INT') { interrupted = true }
  	ssh.loop(0.1) {
  		not interrupted
  	}

  	ports.each do |port|
  		ssh.forward.cancel_local port + offset
  	end
  end
end

def connect
  # http://github.com/jamis/net-ssh/blob/master/doc/faq/login_shell.txt
  # http://github.com/jamis/net-ssh/blob/master/doc/faq/request_pty.txt
  #sess = [Net::SSH.start(@host, @user) , Net::SSH.start(@host, @user) , Net::SSH.start(@host, @user) ]
  #channels = open_channels(sess)
  #
  #loop do
  #  break unless process_iteration(sess) do
  #     channels.any? { |ch| !ch[:closed] } 
  #   end
  #end
  
  Net::SSH.start(@host, @user) do |ssh|
    buffer = ""
    @received_header = false
    ssh.open_channel do |channel|
      channel.request_pty do |ch1, success|
            raise "could not request pty!" unless success
          end
      channel.send_channel_request "shell" do |ch, success|
        if success
          puts "user shell started successfully"
        else
          puts "could not start user shell"
        end
      end
      
          channel[:data] ||= ""
          
          #channel.send_data "sh\n"
          #channel.on_open_channelannel
      
          #channel.on_data { |channel1, data| print data }
          channel.on_extended_data { |channel1, type, data| STDERR.puts data }
          channel.on_close do 
            puts "on close"
            exit
          end
          channel.on_eof do |channel3|
            puts "on eof"
            exit
          end
          #channel.on_process do |channel2, data|
            
          #end
          
          

           channel.on_data do |channel2, data|
             channel[:data] += data
             print '!'
             STDOUT.flush
           end

           channel.on_process do |channel2|
              print '.'
             if !channel[:data].empty?
               while !( channel[:data] =~ /^.*?\n/)
                 sleep 0.1 
                 print '.'
                 STDOUT.flush
               end
               
               print channel[:data]

               STDOUT.flush
               #channel.close
               channel[:data] = ""
             end
             channel.send_data $stdin.readline rescue EOFError
             channel.send_data "\n"
             STDOUT.flush
             sleep 3
           end
          

        	

      #end # pty

    end

     first_login = true
   	trap('INT') { puts "NIGHT!"; exit 1 }
   	begin
       ssh.loop(0.1) do 
         #sleep 0.5
         #channel.active?
         true
       end
   	rescue  => ex
   	  puts "ERROR:"
   	  puts ex.message
 	  end

  end   # Net::SSH  
    
end


