
#require 'drydock/mixins'
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
        %w{solutious.heroku.com/ip}.each do |sponge|
          ipstr = Net::HTTP.get(URI.parse("http://#{sponge}")) || ''
          ip = /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(ipstr).to_s
          break if ip && !ip.empty?
        end
      rescue SocketError, Errno::ETIMEDOUT => ex
        Rudy::Huxtable.le "Connection Error. Check your internets!"
      end
      ip
    end
    
    # Return the local IP address which receives external traffic
    # from: http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
    # NOTE: This <em>does not</em> open a connection to the IP address. 
    def internal_ip_address
      # turn off reverse DNS resolution temporarily 
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true   
      ip = UDPSocket.open {|s| s.connect('75.101.137.7', 1); s.addr.last } # Solutious IP
      ip
    ensure  
      Socket.do_not_reverse_lookup = orig
    end
    
    # Generates a canonical tag name in the form:
    #     2009-12-31-USER-SUFFIX
    # where USER is equal to the user executing the Rudy process and 
    # SUFFIX is equal to +suffix+ (optional)
    def generate_tag(suffix=nil)
      n = DateTime.now
      y, m = n.year.to_s.rjust(4, "20"), n.month.to_s.rjust(2, "0")
      d, u = n.mday.to_s.rjust(2, "0"), Rudy.sysinfo.user
      criteria = [y, m, d, u]
      criteria << suffix unless suffix.nil? || suffix.empty?
      criteria.join Rudy::DELIM 
    end
    
    # Wait for something to happen. 
    # * +duration+ seconds to wait between tries (default: 2).
    # * +max+ maximum time to wait (default: 240). Throws an exception when exceeded.
    # * +logger+ IO object to print +dot+ to.
    # * +msg+ the message to print before executing the block. 
    # * +bells+ number of terminal bells to ring. Set to nil or false to keep the waiter silent
    #
    # The +check+ block must return false while waiting. Once it returns true
    # the waiter will return true too.
    def waiter(duration=2, max=240, logger=STDOUT, msg=nil, bells=0, &check)
      # TODO: Move to Drydock. [ed-why?]
      raise "The waiter needs a block!" unless check
      duration = 1 if duration < 1
      max = duration*2 if max < duration
      dot = '.'
      begin
        if msg && logger
          logger.print msg 
          logger.flush
        end
        Timeout::timeout(max) do
          while !check.call
            sleep duration
            logger.print dot if logger.respond_to?(:print)
            logger.flush if logger.respond_to?(:flush)
          end
        end
      rescue Timeout::Error => ex
        retry if Annoy.pose_question(" Keep waiting?\a ", /yes|y|ya|sure|you bet!/i, logger)
        return false
      end
      
      if msg && logger
        logger.puts
        logger.flush
      end
      
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

    # Return a string ID without the identifier. e.g. key-stage-app-root => stage-app-root
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
      #colour = :black unless Drydock::Console.valid_colour?(colour)
      size, colour = size.to_sym, colour.to_sym
      sprintf(banners[size], msg).bright.att(:reverse)
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
      if Rudy.sysinfo.vm == :java
        begin
          iadd = Java::InetSocketAddress.new host, port      
          socket = Java::Socket.new
          socket.connect iadd, wait * 1000  # milliseconds
          success = !socket.isClosed && socket.isConnected
        rescue NativeException => ex
          puts ex.message, ex.backtrace if Rudy.debug?
          false
        end
      else 
        begin
          status = Timeout::timeout(wait) do
            socket = Socket.new( AF_INET, SOCK_STREAM, 0 )
            sockaddr = Socket.pack_sockaddr_in( port, host )
            socket.connect( sockaddr )
          end
          true
        rescue Errno::EAFNOSUPPORT, Errno::ECONNREFUSED, SocketError, Timeout::Error => ex
          puts ex.class, ex.message, ex.backtrace if Rudy.debug?
          false
        end
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
    def write_to_file(filename, content, mode, chmod=600)
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
      
  end
end

# = Rudy::Utils::RSSReader
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
      Rudy::Huxtable.le "Connection Error. Check your internets!"
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