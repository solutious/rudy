
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

    autoload :Backups, 'rudy/cli/backups'
    autoload :Candy, 'rudy/cli/candy'
    autoload :Config, 'rudy/cli/config'
    autoload :Disks, 'rudy/cli/disks'
    autoload :Images, 'rudy/cli/images'
    autoload :Info, 'rudy/cli/info'
    autoload :Keypairs, 'rudy/cli/keypairs'
    autoload :Machines, 'rudy/cli/machines'
    autoload :Metadata, 'rudy/cli/metadata'
    autoload :Networks, 'rudy/cli/networks'
    autoload :Routines, 'rudy/cli/routines'
    
    module AWS
      module EC2
        autoload :Info, 'rudy/cli/aws/ec2/info'
        autoload :Candy, 'rudy/cli/aws/ec2/candy'
        autoload :Addresses, 'rudy/cli/aws/ec2/addresses'
        autoload :Addresses, 'rudy/cli/aws/ec2/addresses'
        autoload :Groups, 'rudy/cli/aws/ec2/groups'
        autoload :Images, 'rudy/cli/aws/ec2/images'
        autoload :Instances, 'rudy/cli/aws/ec2/instances'
        autoload :Keypairs, 'rudy/cli/aws/ec2/keypairs'
        autoload :Snapshots, 'rudy/cli/aws/ec2/snapshots'
        autoload :Volumes, 'rudy/cli/aws/ec2/volumes'
        autoload :Zones, 'rudy/cli/aws/ec2/zones'
      end
      module SDB
        autoload :Domains, 'rudy/cli/aws/sdb/domains'
        autoload :Objects, 'rudy/cli/aws/sdb/objects'
        autoload :Select, 'rudy/cli/aws/sdb/select'
      end
      module S3
        autoload :Buckets, 'rudy/cli/aws/s3/buckets'
        autoload :Store, 'rudy/cli/aws/s3/store'
      end
    end
  end
end



