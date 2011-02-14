
unless defined?(RUDY_HOME)
  RUDY_HOME = File.join(File.dirname(__FILE__), '..') 
  RUDY_LIB = File.join(File.dirname(__FILE__), '..', 'lib')
end

local_libs = %w{net-ssh net-scp aws-s3 caesars drydock rye storable sysinfo annoy gibbler}
local_libs.each { |dir| $:.unshift File.join(RUDY_HOME, '..', dir, 'lib') }
require 'rubygems'

begin; require 'json'; rescue LoadError; end # Silence!

require 'digest/md5'
require 'stringio'
require 'ostruct'
require 'logger'
require 'socket'
require 'resolv'

require 'gibbler/aliases'
require 'rudy/mixins'
require 'storable'
require 'sysinfo'
require 'attic'

require 'rye'
require 'annoy'
require 'tempfile'
require 'timeout'
require 'yaml'

# = Rudy
#
#
# Rudy is a development and deployment tool for the Amazon Elastic Compute Cloud
# (EC2). <a href="http://solutious.com/projects/rudy/getting-started">Getting Started</a> today!
# 
# 
module Rudy
  extend self
  
  module VERSION #:nodoc:
    unless defined?(MAJOR)
      MAJOR = 0.freeze
      MINOR = 9.freeze
      TINY  = 8.freeze
      PATCH = '020'.freeze
    end
    def self.to_s; [MAJOR, MINOR, TINY, PATCH].join('.'); end
    def self.to_f; self.to_s.to_f; end
  end
  
  def Rudy.sysinfo
    @@sysinfo = SysInfo.new.freeze if @@sysinfo.nil?
    @@sysinfo
  end
  def sysinfo; Rudy.sysinfo;  end
    
  unless defined? Rudy::DOMAIN # We can assume all constants are defined
    
    @@quiet = false
    @@auto = false
    @@debug = false
    @@sysinfo = nil
    
    # SimpleDB accepts dashes in the domain name on creation and with the query syntax. 
    # However, with select syntax it says: "The specified query expression syntax is not valid"
    DOMAIN = "rudy_state".freeze
    DELIM  = '-'.freeze
  
    CONFIG_DIR = File.join(Rudy.sysinfo.home, '.rudy').freeze
    CONFIG_FILE = File.join(Rudy::CONFIG_DIR, 'config').freeze
    SSH_KEY_DIR = File.expand_path('~/.ssh').freeze
    
    DEFAULT_ZONE = :'us-east-1b'.freeze 
    DEFAULT_REGION = DEFAULT_ZONE.to_s.gsub(/[a-z]$/, '').to_sym.freeze
    DEFAULT_ENVIRONMENT = :stage.freeze
    DEFAULT_ROLE = :app.freeze

    DEFAULT_EC2_HOST = "ec2.amazonaws.com"
    DEFAULT_EC2_PORT = 443
    
    DEFAULT_WINDOWS_FS = 'ntfs'
    DEFAULT_LINUX_FS = 'ext3'
    
    DEFAULT_WINDOWS_DEVICE = 'xvdf'
    DEFAULT_LINUX_DEVICE = '/dev/sdh'
    
    MAX_INSTANCES = 20.freeze
    
    ID_MAP = {
      :instance    => 'i',
      :machine     => 'm',
      :reservation => 'r',
      :pkey        => 'pk',
      :volume      => 'vol',
      :kernel      => 'aki',
      :image       => 'ami',
      :ramdisk     => 'ari',
      :group       => 'grp',
      :log         => 'log',
      :key         => 'key',
      :dns_public  => 'ec2',
      :disk        => 'disk',
      :backup      => 'back',
      :snapshot    => 'snap',
      :cert        => 'cert',
      :dns_private => 'domU'
    }.freeze

  end
  
  def Rudy.quiet?; @@quiet == true; end
  def Rudy.enable_quiet; @@quiet = true; end
  def Rudy.disable_quiet; @@quiet = false; end
  
  def Rudy.auto?; @@auto == true; end
  def Rudy.enable_auto; @@auto = true; end
  def Rudy.disable_auto; @@auto = false; end
  
  def Rudy.debug?; @@debug == true; end
  def Rudy.enable_debug; @@debug = true; end
  def Rudy.disable_debug; @@debug = false; end

  require 'rudy/exceptions'
  require 'rudy/utils'                      # The
  require 'rudy/global'                     # order    
  require 'rudy/config'                     # of 
  require 'rudy/huxtable'                   # requires
  autoload :AWS, 'rudy/aws'                 # is
  autoload :Metadata, 'rudy/metadata'       # super
  autoload :Machines, 'rudy/machines'       # important.
  autoload :Backups, 'rudy/backups'
  autoload :Disks, 'rudy/disks'
  autoload :Routines, 'rudy/routines'
  
end

if Rudy.sysinfo.vm == :java
  require 'java'
  module Java
    include_class java.net.Socket unless defined?(Java::Socket)
    include_class java.net.InetSocketAddress unless defined?(Java::InetSocketAddress)
  end
end

