# ---
#
# based on: http://blog.leetsoft.com/2006/03/14/simple-encryption
#
# 
# Some scraps:
#p pem = Base64.encode64(k.key.to_pem)
#p Digest::MD5.hexdigest(pem).upcase
#p        
#k.key.public_key
##p k.key.to_s == k.key.to_pem   # => true
# +++


require 'base64'  # Added, to fix called to Base64

# IF NOT JRUBY
require 'openssl'
# ELSE
#module JRuby
#   module OpenSSL
#     GEM_ONLY = false unless defined?(GEM_ONLY)
#   end
# end
#
# if JRuby::OpenSSL::GEM_ONLY
#   require 'jruby/openssl/gem'
# else
#   module OpenSSL
#     class OpenSSLError < StandardError; end
#     # These require the gem
#     %w[
#     ASN1
#     BN
#     Cipher
#     Config
#     Netscape
#     PKCS7
#     PKey
#     Random
#     SSL
#     X509
#     ].each {|c| autoload c, "jruby/openssl/gem"}
#   end
#   require "jruby/openssl/builtin"
# end
#end
 
module Crypto
  VERSION = 1.0
  
  def self.create_keys(bits = 2048)
    pk = OpenSSL::PKey::RSA.new(bits)
  end
  
  @@digest = OpenSSL::Digest::Digest.new("sha1")
  def self.sign(secret, string)
    sig = OpenSSL::HMAC.hexdigest(@@digest, secret, string).strip
    #sig.gsub(/\+/, "%2b")
  end
  def self.aws_sign(secret, string)
    Base64.encode64(self.sign(secret, string)).strip
  end
  
  class Key
    attr_reader :data, :key
    
    def initialize(data)
      @public = (data =~ /^-----BEGIN (RSA|DSA) PRIVATE KEY-----$/).nil?
      @key = OpenSSL::PKey::RSA.new(data)
    end  

    def self.from_file(filename)    
      self.new File.read( filename )
    end
  
    def encrypt(text)
      Base64.encode64(@key.send("#{type}_encrypt", text))
    end
    
    def decrypt(text)
      @key.send("#{type}_decrypt", Base64.decode64(text))
    end
  
    def private?()  !@public; end # Added () and ;
  
    def public?()   @public;  end # Added () and ;
    
    def type
      @public ? :public : :private
    end
  end
end