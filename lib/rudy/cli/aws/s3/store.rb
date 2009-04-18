

module Rudy; module CLI; 
module AWS; module S3;
  
  class Store < Rudy::CLI::CommandBase
    
    def store_valid?
      raise "No path specified" unless @argv.path
      raise "No bucket specified" unless @option.bucket
      true
    end
    def store
      s3 = Rudy::AWS::S3.new(@@global.accesskey, @@global.secretkey, @@global.region)
      puts "Success: %s" % s3.store(@argv.path, @option.bucket)
      
    end
    
  end
  
end;end
end;end