
unless defined?(RUDY_HOME)
  RUDY_HOME = File.join(File.dirname(__FILE__), '..') 
  RUDY_LIB = File.join(File.dirname(__FILE__), '..', 'lib')
end


require 'digest/md5'
require 'stringio'
require 'ostruct'
require 'yaml'
require 'socket'
require 'timeout'
require 'tempfile'

require 'storable'
require 'console'
require 'sysinfo'
require 'annoy'

require 'rye'

require 'net/ssh'
require 'net/scp'
require 'net/ssh/multi'
require 'net/ssh/gateway'


require 'logger'

# = Rudy
#
# == About
#
# Rudy is a development and deployment tool for the Amazon Elastic Compute Cloud
# (EC2). There are two interfaces: a command-line executable and a Ruby library.
# You can use Rudy as a development tool to simply the management of instances, 
# security groups, etc... on an ad-hoc basic. You can also define complex machine 
# environments using a simple domain specific language (DSL) and use Rudy to build
# and deploy these environments. 
#
#
# == Status: Alpha
# 
# The current release (0.5) is not ready for general production use. Use it for 
# exploring EC2 and operating your development / ad-hoc instances. We've put in 
# a lot of effort to make sure Rudy plays safe, but it's possible we missed
# something. That's why we consider it alpha code. 
#
# To get started right away, try:
#
#     $ rudy -h
#     $ rudy show-commands
#
# And if you're feeling particularly saucey, try Rudy's REPL interface:
#
#     $ ird
# 
# == Next Release (0.6): May 2009.
#
#     $ rudy slogan
#     Rudy: Not your grandparent's deployment tool! 
#
#
module Rudy
  extend self
  
  module VERSION #:nodoc:
    unless defined?(MAJOR)
      MAJOR = 0.freeze
      MINOR = 6.freeze
      TINY  = 0.freeze
    end
    def self.to_s; [MAJOR, MINOR, TINY].join('.'); end
    def self.to_f; self.to_s.to_f; end
  end
  
  unless defined?(Rudy::DOMAIN) # We can assume all constants are defined
    # SimpleDB accepts dashes in the domain name on creation and with the query syntax. 
    # However, with select syntax it says: "The specified query expression syntax is not valid"
    DOMAIN = "rudy_state".freeze
    DELIM  = '-'.freeze
  
    CONFIG_DIR = File.join(ENV['HOME'] || ENV['USERPROFILE'], '.rudy').freeze
    CONFIG_FILE = File.join(Rudy::CONFIG_DIR, 'config').freeze
    
    DEFAULT_REGION = 'us-east-1'.freeze 
    DEFAULT_ZONE = 'us-east-1b'.freeze 
    DEFAULT_ENVIRONMENT = 'stage'.freeze
    DEFAULT_ROLE = 'app'.freeze
    DEFAULT_POSITION = '01'.freeze
    
    DEFAULT_USER = 'rudy'.freeze
    
    DEFAULT_EC2_HOST = "ec2.amazonaws.com"
    DEFAULT_EC2_PORT = 443
    
    MAX_INSTANCES = 2.freeze
    
    SUPPORTED_SCM_NAMES = [:svn, :git].freeze
  
    ID_MAP = {
      :instance => 'i',
      :disk => 'disk',
      :backup => 'back',
      :machine => 'm',
      :volume => 'vol',
      :snapshot => 'snap',
      :kernel => 'aki',
      :image => 'ami',
      :ram => 'ari',
      :log => 'log',
      :key => 'key',
      :awspk => 'pk',
      :awscert => 'cert',
      :reservation => 'r',
      :dns_public => 'ec2',
      :dns_private => 'domU',
    }.freeze
    
    @@quiet = false
    @@debug = false
    @@sysinfo = SystemInfo.new.freeze
    
  end
  
  def Rudy.debug?; @@debug == true; end
  def Rudy.quiet?; @@quiet == true; end
  def Rudy.enable_debug; @@debug = true; end
  def Rudy.enable_quiet; @@quiet = true; end
  def Rudy.disable_debug; @@debug = false; end
  def Rudy.disable_quiet; @@quiet = false; end
  
  def Rudy.sysinfo; @@sysinfo; end
  def sysinfo; @@sysinfo;  end
  
  class Error < RuntimeError
    def initialize(obj); @obj = obj; end
    def message; "#{self.class}: #{@obj}"; end
  end
  class InsecureKeyPermissions < Rudy::Error
    def message
      lines = ["Insecure file permissions for #{@obj}"]
      lines << "Try: chmod 600 #{@obj}"
      lines.join($/)
    end
  end
  class NoConfig < Rudy::Error
    def message; "No AWS credentials. Check your configs!"; end
  end
  class ServiceUnavailable < Rudy::Error
    def message; "#{@obj} is not available. Check your internets!"; end
  end
  class MachineGroupAlreadyRunning < Rudy::Error; 
    def message; "Machine group #{@obj} is already running."; end
  end
  class MachineGroupNotDefined < Rudy::Error; 
    def message; "Machine group #{@obj} is not defined."; end
  end
end

require 'rudy/utils'      # The
require 'rudy/global'     # order    
require 'rudy/config'     # of 
require 'rudy/huxtable'   # requires
require 'rudy/aws'        # is
require 'rudy/metadata'   # important

require 'rudy/machine'
require 'rudy/routine'


