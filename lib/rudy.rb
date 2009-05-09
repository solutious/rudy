
unless defined?(RUDY_HOME)
  RUDY_HOME = File.join(File.dirname(__FILE__), '..') 
  RUDY_LIB = File.join(File.dirname(__FILE__), '..', 'lib')
end

$:.unshift File.join(RUDY_HOME, 'vendor', 'highline-1.5.1', 'lib')
local_libs = %w{net-scp amazon-ec2 aws-s3 caesars drydock rye storable sysinfo annoy}
local_libs.each { |dir| $:.unshift File.join(RUDY_HOME, '..', dir, 'lib') }

require 'digest/md5'
require 'stringio'
require 'ostruct'
require 'yaml'
require 'json'
require 'logger'
require 'socket'
require 'timeout'
require 'tempfile'
require 'mixins/hash'
require 'storable'
require 'sysinfo'
require 'annoy'
require 'rye'



# = Rudy
#
#
# Rudy is a development and deployment tool for the Amazon Elastic Compute Cloud
# (EC2). <a href="wiki.github.com/solutious/rudy/getting-started">Getting Started</a> today!
# 
# 
module Rudy
  extend self
  
  module VERSION #:nodoc:
    unless defined?(MAJOR)
      MAJOR = 0.freeze
      MINOR = 8.freeze
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
    
    MAX_INSTANCES = 5.freeze
    
    SUPPORTED_SCM_NAMES = [:svn, :git].freeze
  
    ID_MAP = {
      :disk => 'disk',
      :instance => 'i',
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
    @@sysinfo = SysInfo.new.freeze
    
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
    def initialize(obj=nil); @obj = obj; end
    def message; "#{self.class}: #{@obj}"; end
  end
  class InsecureKeyPermissions < Rudy::Error
    def message
      lines = ["Insecure file permissions for #{@obj}"]
      lines << "Try: chmod 600 #{@obj}"
      lines.join($/)
    end
  end
  
  #--
  # TODO: Update exception Syntax based on:
  # http://blog.rubybestpractices.com/posts/gregory/anonymous_class_hacks.html
  #++
  class NoConfig < Rudy::Error
    def message; "No configuration found!"; end
  end
  class NoGlobal < Rudy::Error
    def message; "No globals defined!"; end
  end
  class NoMachinesConfig < Rudy::Error
    def message; "No machines configuration. Check your configs!"; end
  end
  class NoRoutinesConfig < Rudy::Error
    def message; "No routines configuration. Check your configs!"; end
  end
  class ServiceUnavailable < Rudy::Error
    def message; "#{@obj} is not available. Check your internets!"; end
  end
  class MachineGroupAlreadyRunning < Rudy::Error
    def message; "Machine group #{@obj} is already running."; end
  end
  class MachineGroupNotRunning < Rudy::Error
    def message; "Machine group #{@obj} is not running."; end
  end
  class MachineGroupNotDefined < Rudy::Error 
    def message; "#{@obj} is not defined in machines config."; end
  end
  class PrivateKeyFileExists < Rudy::Error
    def message; "Private key #{@obj} already exists."; end
  end
  class PrivateKeyNotFound < Rudy::Error
    def message; "Private key file #{@obj} not found."; end
  end
end

require 'rudy/utils'      # The
require 'rudy/global'     # order    
require 'rudy/config'     # of 
require 'rudy/huxtable'   # requires
require 'rudy/aws'        # is
require 'rudy/metadata'   # important
require 'rudy/machines'
require 'rudy/routines'
require 'rudy/scm'


