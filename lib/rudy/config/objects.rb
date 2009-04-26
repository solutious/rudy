

class Rudy::Config
  class Machines < Caesars
  end
  
  
  class Accounts < Caesars
    def valid?
      (!aws.nil? && !aws.accesskey.nil? && !aws.secretkey.nil?) &&
      (!aws.account.empty? && !aws.accesskey.empty? && !aws.secretkey.empty?) 
    end
  end

  class Defaults < Caesars
  end

  class Networks < Caesars
  end
  
  class Controls < Caesars
  end
  
  class Routines < Caesars
    
    forced_hash :create
    forced_hash :destroy
    forced_hash :restore
    forced_hash :mount
    forced_hash :before
    
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