
module Rudy; module CLI; 
module AWS; module SDB;
  
  class Select < Rudy::CLI::CommandBase
    
    def query_valid?
      raise "No select query supplied" if @argv.empty?
      true
    end
    
    def query
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      results = @sdb.select @argv.query 
      return if results.nil?
      results.each do |r|
        p r
      end
    end
  end
  
end; end
end; end