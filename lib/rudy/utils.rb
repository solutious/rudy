
require 'socket'
require 'open-uri'
require 'date'

require 'timeout'

module Rudy
  
  # A motley collection of methods that Rudy loves to call!
  module Utils
    extend self
    include Socket::Constants
    
    # Return the external IP address (the one seen by the internet)
    def external_ip_address
      ip = nil
      begin
        %w{solutious.com/ip/ myip.dk/ whatismyip.com }.each do |sponge| # w/ backup
          ipstr = Net::HTTP.get(URI.parse("http://#{sponge}")) || ''
          ip = /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(ipstr).to_s
          break if ip && !ip.empty?
        end
      rescue SocketError, Errno::ETIMEDOUT
        STDERR.puts "Connection Error. Check your internets!"
      end
      ip += "/32" if ip
      ip
    end
    
    # Return the local IP address which receives external traffic
    # from: http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
    # NOTE: This <em>does not</em> open a connection to the IP address. 
    def internal_ip_address
      # turn off reverse DNS resolution temporarily 
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true   
      ip = UDPSocket.open {|s| s.connect('75.101.137.7', 1); s.addr.last } # Solutious IP
      ip += "/24" if ip
      ip
    ensure  
      Socket.do_not_reverse_lookup = orig
    end
    
    # Generates a canonical tag name in the form:
    #     rudy-2009-12-31-01
    # where r1 refers to the revision number that day
    def generate_tag(revision=1)
      n = DateTime.now
      y = n.year.to_s.rjust(4, "20")
      m = n.month.to_s.rjust(2, "0")
      d = n.mday.to_s.rjust(2, "0")
      "rudy-%4s-%2s-%2s-r%s" % [y, m, d, revision.to_s.rjust(2, "0")] 
    end
    
    
    
    
    # Determine if we're running directly on EC2 or
    # "some other machine". We do this by checking if
    # the file /etc/ec2/instance-id exists. This
    # file is written by /etc/init.d/rudy-ec2-startup. 
    # NOTE: Is there a way to know definitively that this is EC2?
    # We could make a request to the metadata IP addresses. 
    def Rudy.in_situ?
      File.exists?('/etc/ec2/instance-id')
    end


    # Wait for something to happen. 
    # * +duration+ seconds to wait between tries (default: 2).
    # * +max+ maximum time to wait (default: 120). Throws an exception when exceeded.
    # * +logger+ IO object to print +dot+ to.
    # * +msg+ the message to print on success
    # * +bells+ number of terminal bells to ring
    # Set to nil or false to keep the waiter silent.
    # The block must return false while waiting. Once it returns true
    # the waiter will return true too.
    def waiter(duration=2, max=120, logger=STDOUT, msg=nil, bells=0, &check)
      # TODO: Move to Drydock. [ed-why?]
      raise "The waiter needs a block!" unless check
      duration = 1 if duration < 1
      max = duration*2 if max < duration
      dot = '.'
      begin
        Timeout::timeout(max) do
          while !check.call
            logger.print dot if logger.respond_to?(:print)
            logger.flush if logger.respond_to?(:flush)
            sleep duration
          end
        end
      rescue Timeout::Error => ex
        retry if Annoy.pose_question(" Keep waiting?\a ", /yes|y|ya|sure|you bet!/i, logger)
        return false
      end
      logger.puts msg if msg
      Rudy::Utils.bell(bells, logger)
      true
    end

    # Make a terminal bell chime
    def bell(chimes=1, logger=nil)
      chimes ||= 0
      return unless logger
      chimed = chimes.to_i
      logger.print "\a"*chimes if chimes > 0 && logger
      true # be like Rudy.bug()
    end

    # Have you seen that episode of The Cosby Show where Dizzy Gillespie... ah nevermind.
    def bug(bugid, logger=STDERR)
      logger.puts "You have found a bug! If you want, you can email".color(:red)
      logger.puts 'rudy@solutious.com'.color(:red).bright << " about it. It's bug ##{bugid}.".color(:red)          
      logger.puts "Continuing...".color(:red)
      true # so we can string it together like: bug('1') && next if ...
    end

    # Is the given string +str+ an ID of type +identifier+? 
    # * +identifier+ is expected to be a key from ID_MAP
    # * +str+ is a string you're investigating
    def is_id?(identifier, str)
      return false unless identifier && str && known_type?(identifier)
      identifier &&= identifier.to_sym
      str &&= str.to_s.strip
      str.split('-').first == Rudy::ID_MAP[identifier].to_s
    end

    # Returns the object type associated to +str+ or nil if unknown. 
    # * +str+ is a string you're investigating
    def id_type(str)
      return false unless str
      str &&= str.to_s.strip
      (Rudy::ID_MAP.detect { |n,v| v == str.split('-').first } || []).first
    end

    # Is the given +key+ a known type of object?
    def known_type?(key)
      return false unless key
      key &&= key.to_s.to_sym
      Rudy::ID_MAP.has_key?(key)
    end

    # Returns the string identifier associated to this +key+
    def identifier(key)
      key &&= key.to_sym
      return unless Rudy::ID_MAP.has_key?(key)
      Rudy::ID_MAP[key]
    end

    # Return a string ID without the identifier. i.e. key-stage-app-root => stage-app-root
    def noid(str)
      el = str.split('-')
      el.shift
      el.join('-')
    end
    

    # +msg+ The message to return as a banner
    # +size+ One of: :normal (default), :huge
    # +colour+ a valid 
    # Returns a string with styling applying
    def banner(msg, size = :normal, colour = :black)
      return unless msg
      banners = {
        :huge => Rudy::Utils.without_indent(%Q(
        =======================================================
        =======================================================
        !!!!!!!!!   %s   !!!!!!!!!
        =======================================================
        =======================================================)),
        :normal => %Q(============  %s  ============)
      }
      size = :normal unless banners.has_key?(size)
      colour = :black unless Console.valid_colour?(colour)
      size, colour = size.to_sym, colour.to_sym
      sprintf(banners[size], msg).colour(colour).bgcolour(:white).bright
    end

    
    # <tt>require</tt> a glob of files. 
    # * +path+ is a list of path elements which is sent to File.join 
    # and then to Dir.glob. The list of files found are sent to require. 
    # Nothing is returned but LoadError exceptions are caught. The message
    # is printed to STDERR and the program exits with 7. 
    def require_glob(*path)
      begin
        # TODO: Use autoload
        Dir.glob(File.join(*path.flatten)).each do |path|
          require path
        end
      rescue LoadError => ex
        puts "Error: #{ex.message}"
        exit 7
      end
    end

    # Checks whether something is listening to a socket. 
    # * +host+ A hostname
    # * +port+ The port to check
    # * +wait+ The number of seconds to wait for before timing out. 
    #
    # Returns true if +host+ allows a socket connection on +port+. 
    # Returns false if one of the following exceptions is raised:
    # Errno::EAFNOSUPPORT, Errno::ECONNREFUSED, SocketError, Timeout::Error
    #
    def service_available?(host, port, wait=3)
      begin
        status = Timeout::timeout(wait) do
          socket = Socket.new( AF_INET, SOCK_STREAM, 0 )
          sockaddr = Socket.pack_sockaddr_in( port, host )
          socket.connect( sockaddr )
        end
        true
      rescue Errno::EAFNOSUPPORT, Errno::ECONNREFUSED, SocketError, Timeout::Error => ex
        false
      end
    end
    
    
    
    # Capture STDOUT or STDERR to prevent it from being printed. 
    #
    #    capture(:stdout) do
    #      ...
    #    end
    #
    def capture(stream)
      #raise "We can only capture STDOUT or STDERR" unless stream == :stdout || stream == :stderr
      begin
        stream = stream.to_s
        eval "$#{stream} = StringIO.new"
        yield
        result = eval("$#{stream}").read
      ensure
        eval("$#{stream} = #{stream.upcase}")
      end

      result
    end

    # A basic file writer
    def write_to_file(filename, content, mode, chmod=nil)
      mode = (mode == :append) ? 'a' : 'w'
      f = File.open(filename,mode)
      f.puts content
      f.close
      return unless Rudy.sysinfo.os == :unix
      raise "Provided chmod is not a Fixnum (#{chmod})" unless chmod.is_a?(Fixnum)
      File.chmod(chmod, filename)
    end

    # 
    # Generates a string of random alphanumeric characters.
    # * +len+ is the length, an Integer. Default: 8
    # * +safe+ in safe-mode, ambiguous characters are removed (default: true):
    #       i l o 1 0
    def strand( len=8, safe=true )
       chars = ("a".."z").to_a + ("0".."9").to_a
       chars.delete_if { |v| %w(i l o 1 0).member?(v) } if safe
       str = ""
       1.upto(len) { |i| str << chars[rand(chars.size-1)] }
       str
    end
    
    # Returns +str+ with the leading indentation removed. 
    # Stolen from http://github.com/mynyml/unindent/ because it was better.
    def without_indent(str)
      indent = str.split($/).each {|line| !line.strip.empty? }.map {|line| line.index(/[^\s]/) }.compact.min
      str.gsub(/^[[:blank:]]{#{indent}}/, '')
    end
      
    
    
    
    ######### Everything below here is TO BE REMOVED. 
    
    def sh(command, chdir=false, verbose=false)
      prevdir = Dir.pwd
      Dir.chdir chdir if chdir
      puts command if verbose
      system(command)
      Dir.chdir prevdir if chdir
    end


    def ssh_command(host, keypair, user, command=false, printonly=false, verbose=false)
      #puts "CONNECTING TO #{host}..."
      cmd = "ssh -i #{keypair} #{user}@#{host} "
      cmd += " '#{command}'" if command
      puts cmd if verbose
      return cmd if printonly
      # backticks returns STDOUT
      # exec replaces current process (it's just like running ssh)
      # -- UPDATE -- Some problem with exec. "Operation not supported"
      # using system (http://www.mail-archive.com/mongrel-users@rubyforge.org/msg02018.html)
      (command) ? `#{cmd}` : Kernel.system(cmd)
    end

    
    # TODO: This is old and insecure. 
    def scp_command(host, keypair, user, paths, to_path, to_local=false, verbose=false, printonly=false)

      paths = [paths] unless paths.is_a?(Array)
      from_paths = ""
      if to_local
        paths.each do |path|
          from_paths << "#{user}@#{host}:#{path} "
        end  
        #puts "Copying FROM remote TO this machine", $/

      else
        to_path = "#{user}@#{host}:#{to_path}"
        from_paths = paths.join(' ')
        #puts "Copying FROM this machine TO remote", $/
      end


      cmd = "scp -r "
      cmd << "-i #{keypair}" if keypair
      cmd << " #{from_paths} #{to_path}"

      puts cmd if verbose
      printonly ? (puts cmd) : system(cmd)
    end

  end
end

# = RSSReader
#
# A rudimentary way to read an RSS feed as a hash.
# Adapted from: http://snippets.dzone.com/posts/show/68
#
module Rudy::Utils::RSSReader
  extend self
  require 'net/http'
  require 'rexml/document'
  
  # Returns a feed as a hash. 
  # * +uri+ to RSS feed
  def run(uri)
    begin
      xmlstr = Net::HTTP.get(URI.parse(uri))
    rescue SocketError, Errno::ETIMEDOUT
      STDERR.puts "Connection Error. Check your internets!"
    end
    
    xml = REXML::Document.new xmlstr
    
    data = { :items => [] }
    xml.elements.each '//channel' do |item|
      item.elements.each do |e| 
        n = e.name.downcase.gsub(/^dc:(\w)/,"\1").to_sym
        next if n == :item
        data[n] = e.text
      end
    end
    
    #data = {
    #  :title    => xml.root.elements['channel/title'].text,
    #  :link => xml.root.elements['channel/link'].text,
    #  :updated => xml.root.elements['channel/lastBuildDate'].text,
    #  :uri  => uri,
    #  :items    => []
    #}
    #data[:updated] &&= DateTime.parse(data[:updated])
    
    xml.elements.each '//item' do |item|
      new_items = {} and item.elements.each do |e| 
        n = e.name.downcase.gsub(/^dc:(\w)/,"\1").to_sym
        new_items[n] = e.text
      end
      data[:items] << new_items
    end
    data
  end
end