

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Objects < Rudy::CLI::CommandBase
    
    
    def objects_valid?
      raise "Must supply domain" if @argv.empty?
      true
    end
    def objects
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      
      if @argv.key.nil?
        query = "select * from #{@argv.name}"
        items = @sdb.select query
      else
        items = [@sdb.get( @argv.name, @argv.key)]
      end
      
      exit unless items
      
      items.each do |i|
        p i
      end
    end
    
  end
  
end; end
end; end