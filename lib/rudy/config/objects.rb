

class Rudy::Config
  class Machines < Caesars; end
  class Defaults < Caesars; end
  class Networks < Caesars; end
  class Controls < Caesars; end
  class Services < Caesars; end
  class Commands < Caesars
    def init
      # We can't process the Rye::Cmd commands here because the
      # DSL hasn't been parsed yet so Rudy::Config.postprocess
      # called the following postprocess method after parsing.
      @processed = false
    end
    def postprocess
      return if @processed
      self.allow = [self.allow].flatten.compact
      self.allow.each do |cmd|
        Rudy::Config::Routines.forced_array cmd
        Rye::Cmd.module_eval %Q{
          def #{cmd}(*args); cmd(:'#{cmd}', *args); end
        }
      end
      self.disallow = [self.disallow].flatten.compact
      self.disallow.each do |cmd|
        Rudy::Config::Routines.forced_ignore cmd
        # We don't remove the method from Rye:Cmd because we 
        # may need elsewhere in Rudy. Forced ignore ensures
        # the config is not stored anyhow.
      end
      @processed = true
    end
  end
  
  class Accounts < Caesars
    def valid?
      (!aws.nil? && !aws.accesskey.nil? && !aws.secretkey.nil?) &&
      (!aws.account.empty? && !aws.accesskey.empty? && !aws.secretkey.empty?)
    end
  end
  
  class Routines < Caesars
    
    # Disk routines
    forced_hash :create
    forced_hash :destroy
    forced_hash :restore
    forced_hash :mount
    
    # Remote scripts
    forced_hash :before
    forced_hash :before_local
    forced_hash :after
    forced_hash :after_local
    
    # Version control systems
    forced_hash :git
    forced_hash :svn
    
    
    # Add remote shell commands to the DSL as forced Arrays. 
    # Example:
    #     ls :a, :l, "/tmp"  # => :ls => [[:a, :l, "/tmp"]]
    #     ls :o              # => :ls => [[:a, :l, "/tmp"], [:o]]
    # NOTE: Beware of namespace conflicts in other areas of the DSL,
    # specifically shell commands that have the same name as a keyword
    # we want to use in the DSL. This includes commands that were added
    # to Rye::Cmd before Rudy is 'require'd. 
    Rye::Cmd.instance_methods.each do |cmd|
      forced_array cmd
    end
    
  end
end