

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
  
  class Routines < Caesars
    
    forced_hash :create
    forced_hash :destroy
    forced_hash :restore
    forced_hash :mount

  end
end