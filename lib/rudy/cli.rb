
require 'drydock'


module Rudy
    
  # = CLI
  # 
  # These classes provide the functionality for the Command
  # line interfaces. See the bin/ files if you're interested. 
  # 
  module CLI
    
    require 'rudy/cli/execbase'
    require 'rudy/cli/base'
    
    class NoCred < RuntimeError #:nodoc
    end
    
    class Output < Storable
      # TODO: Use for all CLI responses
      # Messages and errors should be in @@global.format
      # Should print messages as they come
    end
    
    
    def self.generate_header(global, config)
      return "" if global.quiet
      header = StringIO.new
      title, name = "RUDY v#{Rudy::VERSION}", config.accounts.aws.name
      now_utc = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      criteria = []
      [:region, :zone, :environment, :role, :position].each do |n|
        key, val = n.to_s.slice(0,1).att, global.send(n) 
        key = 'R' if n == :region
        next unless val
        criteria << "#{key.att}:#{val.to_s.bright}"
      end
      if config.accounts && config.accounts.aws
        if global.verbose > 0
          header.puts '%s -- %s -- %s UTC' % [title, name, now_utc]
        end
        header.puts '[%s]' % [criteria.join("  ")], $/
      end
      header.rewind
      header.read
    end


  end
end

Rudy::Utils.require_glob(RUDY_LIB, 'rudy', 'cli', '**', '*.rb')


