

module Rudy::Routines
  module Base
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :global
  
    def initialize(args={})
      opts = { :config => {}, :logger => STDERR, :global => {}}.merge(opts)
      # Set instance variables
      opts.each_pair { |n,v| self.send("#{n}=", v) if self.respond_to?("#{n}=") }
    end
  end
end