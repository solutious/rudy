

module Rudy
  require 'caesars'
  
  class MachineGroup < Caesars
    def valid?
      true
    end
  end
  class AWSInfo < Caesars
    def valid?
      (!account.nil? && !accesskey.nil? && !secretkey.nil?) &&
      (!account.empty? && !accesskey.empty? && !secretkey.empty?) 
    end
  end
  
  class Config < Caesars::Config
    dsl Rudy::MachineGroup::DSL
    dsl Rudy::AWSInfo::DSL
    
    def postprocess
      # TODO: give caesar attributes setter methods
      #self.awsinfo = File.expand_path(self.awsinfo.cert) if self.awsinfo.cert
      #self.awsinfo.privatekey = File.expand_path(self.awsinfo.privatekey) if self.awsinfo.privatekey
    end
    
  end
end


