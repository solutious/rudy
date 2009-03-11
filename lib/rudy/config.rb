

module Rudy
  require 'caesars'

  class AWSInfo < Caesars
    def valid?
      (!account.nil? && !accesskey.nil? && !secretkey.nil?) &&
      (!account.empty? && !accesskey.empty? && !secretkey.empty?) 
    end
  end

  class Defaults < Caesars
    def valid?
      true
    end
  end
  
  class MachineGroup < Caesars
    def valid?
      true
    end
    
    def create(*args, &b)
      list_handler(:create, *args, &b)
    end
    def destroy(*args, &b)
      list_handler(:destroy, *args, &b)
    end
    def replace(*args, &b)
      list_handler(:replace, *args, &b)
    end
    
    def list_handler(caesars_meth, *args, &b)
      
      return @caesars_properties[caesars_meth] if @caesars_properties.has_key?(caesars_meth) && args.empty? && b.nil?
      return nil if args.empty? && b.nil?
      
      # TODO: This works but it creates a messy double reference
      prev = @caesars_pointer
      @caesars_pointer[caesars_meth] ||= []
      @caesars_pointer[caesars_meth] << Caesars::Hash.new
      @caesars_pointer = @caesars_pointer[caesars_meth].last
      b.call if b
      @caesars_pointer = prev
      
    end
  end
  
  class Config < Caesars::Config
    dsl Rudy::AWSInfo::DSL
    dsl Rudy::Defaults::DSL
    dsl Rudy::MachineGroup::DSL
    
    def postprocess
      # TODO: give caesar attributes setter methods
      #self.awsinfo = File.expand_path(self.awsinfo.cert) if self.awsinfo.cert
      #self.awsinfo.privatekey = File.expand_path(self.awsinfo.privatekey) if self.awsinfo.privatekey
    end
    
  end
end


