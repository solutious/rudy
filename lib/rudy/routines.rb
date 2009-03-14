

module Rudy::Routines
  module Base
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :global
  
    def initialize(opts={})
      opts = { :config => {}, :logger => STDERR, :global => {}}.merge(opts)
      # Set instance variables
      opts.each_pair { |n,v| self.send("#{n}=", v) if self.respond_to?("#{n}=") }
    end
    
    def keypairpath(name=nil)
      name ||= @global.user
      raise "No default user configured" unless name
      kp = @config.machines.find(@global.environment, @global.role, :users, name, :keypair2)
      kp ||= @config.machines.find(@global.environment, :users, name, :keypair)
      kp ||= @config.machines.find(:users, name, :keypair)
      kp &&= File.expand_path(kp)
      kp
    end
    def has_keypair?(name=nil)
      kp = keypairpath(name)
      (!kp.nil? && File.exists?(kp))
    end
    
  end
end