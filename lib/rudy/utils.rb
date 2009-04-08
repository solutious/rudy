
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
      %w{solutious.com/ip myip.dk/ whatismyip.com }.each do |sponge| # w/ backup
        ip = (open("http://#{sponge}") { |f| /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(f.read) }).to_s rescue nil
        break if !ip.nil?
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
      raise "Provided chmod is not a Fixnum" unless chmod.is_a?(Fixnum)
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
    
    # Returns +str+ with the average leading indentation removed. 
    # Useful for keeping inline codeblocks spaced with code. 
    def without_indent(str)
      # TODO: A better implementation: check how many leading spaces each line has in common. 
      lines = str.split($/)
      lspaces = (lines.inject(0) {|total,line| total += (line.scan(/^\s+/).first || '').size } / lines.size)
      lines.collect { |line| line.gsub(/^\s{#{lspaces}}/, '') }.join($/)
    end


  end
end