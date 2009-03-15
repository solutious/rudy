
#
# No Ruby 1.9.1 support. Only 1.8.x for now :[
unless RUBY_VERSION < "1.9"
  puts "Sorry! We're using the right_aws gem and it doesn't support Ruby 1.9 (md5 error)."
  exit 1
end

require 'digest/md5'
require 'stringio'
require 'ostruct'
require 'yaml'
require 'socket'
require 'tempfile'
require 'timeout'

require 'console'
require 'storable'

require 'net/ssh'
require 'net/ssh/gateway'
require 'net/ssh/multi'
require 'net/scp'



module Rudy #:nodoc:
  RUDY_DOMAIN = "rudy_state"
  RUDY_DELIM  = '-'
  
  RUDY_CONFIG_DIR = File.join(ENV['HOME'] || ENV['USERPROFILE'], '.rudy')
  RUDY_CONFIG_FILE = File.join(RUDY_CONFIG_DIR, 'config')
  
  DEFAULT_REGION = 'us-east-1'
  DEFAULT_ZONE = 'us-east-1b'
  DEFAULT_ENVIRONMENT = 'stage'
  DEFAULT_ROLE = 'app'
  DEFAULT_POSITION = '01'
  
  DEFAULT_USER = 'rudy'
  
  SUPPORTED_SCM_NAMES = [:svn, :git]
  
  module VERSION #:nodoc:
    MAJOR = 0.freeze unless defined? MAJOR
    MINOR = 4.freeze unless defined? MINOR
    TINY  = 0.freeze unless defined? TINY
    def self.to_s
      [MAJOR, MINOR, TINY].join('.')
    end
    def self.to_f
      self.to_s.to_f
    end
  end
  
  # Determine if we're running directly on EC2 or
  # "some other machine". We do this by checking if
  # the file /etc/ec2/instance-id exists. This
  # file is written by /etc/init.d/rudy-ec2-startup. 
  # NOTE: Is there a way to know definitively that this is EC2?
  # We could make a request to the metadata IP addresses. 
  def self.in_situ?
    File.exists?('/etc/ec2/instance-id')
  end
end

require 'rudy/aws'
require 'rudy/cli'
require 'rudy/utils'
require 'rudy/config'
require 'rudy/metadata'
require 'rudy/routines'
require 'rudy/huxtable'
require 'rudy/machines'


# Require CLI, MetaData, Routines, and SCM classes
begin
  # TODO: Use autoload
  Dir.glob(File.join(RUDY_LIB, 'rudy', '{cli,metadata,routines,scm}', "*.rb")).each do |path|
    require path
  end
rescue LoadError => ex
  puts "Error: #{ex.message}"
  exit 1
end


# Capture STDOUT or STDERR to prevent it from being printed. 
#
#    capture(:stdout) do
#      ...
#    end
#
def capture(stream)
  #raise "We can only capture STDOUT or STDERR" unless stream == :stdout || stream == :stderr
  
  # I'm using this to trap the annoying right_aws "peer certificate" warning.
  # TODO: discover source of annoying right_aws warning and give it a hiding.
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

# Wait for something to happen. 
# * +duration+ seconds to wait between tries (default: 2).
# * +max+ maximum time to wait (default: 120). Throws an exception when exceeded.
# * +dot+ the character to print after each attempt (default: .). 
# Set to nil or false to keep the waiter silent.
# * +logger+ IO object to print +dot+ to.
# The block must return false while waiting. Once it returns true
# the waiter will return true.
def waiter(duration=2, max=120, dot='.', logger=STDOUT, &b)
  raise "The waiter needs a block!" unless b
  duration = 1 if duration < 1
  max = duration*2 if max < duration
  begin
    success = Timeout::timeout(max) do
      while !b.call
        sleep duration
        logger.print dot if dot && logger.respond_to?(:print)
        logger.flush if logger.respond_to?(:flush)
      end
    end
  rescue Timeout::Error => ex
    retry if pose_question(" Keep waiting? ", /yes|y|ya|sure|you bet!/i, @logger)
    raise ex # We won't get here unless the question fails
  end
  success
end

def write_to_file(filename, content, type)
  type = (type == :append) ? 'a' : 'w'
  f = File.open(filename,type)
  f.puts content
  f.close
end

def pose_question(msg, exp, logger=STDOUT)
  return true unless STDIN.tty? # Only ask a question if there's a human
  exp &&= Regexp.new exp
  logger.print msg 
  logger.flush if logger.respond_to?(:flush)
  ans = (STDIN.gets || "").gsub(/["']/, '')
  exp.match(ans)
end

def are_you_sure?(len=3)
  return true unless STDIN.tty? # Only ask a question if there's a human 
  
  challenge = strand len
  STDOUT.print "Are you sure? To continue type \"#{challenge}\": "
  STDOUT.flush
  if ((STDIN.gets || "").gsub(/["']/, '') =~ /^#{challenge}$/)
    true
  else
    puts "Nothing changed"
    exit 0
  end
end
    
# 
# Generates a string of random alphanumeric characters
# These are used as IDs throughout the system
def strand( len=8, safe=true )
   chars = ("a".."z").to_a + ("0".."9").to_a
   chars = [("a".."h").to_a, "j", "k", "m", "n", ("p".."z").to_a, ("2".."9").to_a].flatten if safe
   newpass = ""
   1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
   newpass
end

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


def scp_command(host, keypair, user, paths, to_path, to_local=false, verbose=false, printonly=false)
  
  paths = [paths] unless paths.is_a?(Array)
  from_paths = ""
  if to_local
    paths.each do |path|
      from_paths << "#{user}@#{host}:#{path} "
    end  
    puts "Copying FROM remote TO this machine", $/
    
  else
    to_path = "#{user}@#{host}:#{to_path}"
    from_paths = paths.join(' ')
    puts "Copying FROM this machine TO remote", $/
  end
  
  
  cmd = "scp -r -i #{keypair} #{from_paths} #{to_path}"

  puts cmd if verbose
  printonly ? (puts cmd) : system(cmd)
end


# Returns +str+ with the average leading indentation removed. 
# Useful for keeping inline codeblocks spaced with code. 
def without_indent(str)
  lines = str.split($/)
  lspaces = (lines.inject(0) {|total,line| total += (line.scan(/^\s+/).first || '').size } / lines.size) + 1
  lines.collect { |line| line.gsub(/^\s{#{lspaces}}/, '') }.join($/)
end



