

module Rudy; module CLI; 
module AWS; module S3;
  
  class Buckets < Rudy::CLI::CommandBase
    
    
    def buckets
      raise "No bucket name supplied" if !@argv.name && @option.list
      s3 = Rudy::AWS::S3.new(@@global.accesskey, @@global.secretkey, @@global.region)
      unless @option.list
        (s3.list_buckets || []).each do |b|
          puts b.name
        end
      else
        puts "All objects in #{@argv.name}:"
        (s3.list_bucket_objects(@argv.name) || []).each do |o|
          puts o
        end
      end
    end
    
    def create_buckets_valid?
      raise "No bucket name supplied" unless @argv.name
      true
    end
    def create_buckets
      s3 = Rudy::AWS::S3.new(@@global.accesskey, @@global.secretkey, @@global.region)
      s3.create_bucket(@argv.name, @option.location)
      buckets
    end
    
    def destroy_buckets_valid?
      raise "No bucket name supplied" unless @argv.name
      true
    end
    def destroy_buckets
      execute_check(:medium)
      s3 = Rudy::AWS::S3.new(@@global.accesskey, @@global.secretkey, @@global.region)
      s3.destroy_bucket(@argv.name)
      buckets
    end
    
    
  end
  
end; end
end; end