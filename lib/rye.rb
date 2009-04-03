
require 'rubygems' unless defined? Gem
require 'sysinfo'
require 'escape'
require 'thread'
require 'highline'
require 'rye/box'

# = Rye
# An abstration for local and remote commands (via SSH). 
# 
# Inspired by/stolen from:
# http://github.com/adamwiggins/rush
# http://github.com/jamis/capistrano/blob/master/lib/capistrano/shell.rb
# http://www.nofluffjuststuff.com/blog/david_bock/2008/10/ruby_s_closure_cleanup_idiom_and_net_ssh.html
# http://groups.google.com/group/ruby-talk-google/browse_thread/thread/674a6f6de15ceb49?pli=1
# http://paste.lisp.org/display/6912
#
module Rye
  extend self
  unless defined?(SYSINFO)
    VERSION = 0.1.freeze
    SYSINFO = SystemInfo.new.freeze
  end
  
  def Rye.sysinfo; SYSINFO; end
  def sysinfo; SYSINFO;  end
  
  class CommandNotFound < RuntimeError; end
  
  
  

end

