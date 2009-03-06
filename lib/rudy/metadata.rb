
require 'aws_sdb'

module Rudy
  module MetaData
    attr_accessor :sdb
    attr_accessor :ec2
    
    def initalize(sdb, ec2)
      @sdb = sdb
      @ec2 = ec2
    end
    
  end
  
  module MetaData
    
    module ObjectBase
      extend self
      

      
    end
    
  end
end