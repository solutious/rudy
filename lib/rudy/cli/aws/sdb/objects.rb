

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Objects < Rudy::CLI::CommandBase
    
    
    def objects_valid?
      raise "Usage: rudy-sdb objects DOMAIN" if @argv.empty?
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
    
    def objects_destroy_valid?
      raise "Usage: rudy-sdb objects -D DOMAIN OBJECTNAME" if @argv.size < 2
      true
    end
    def objects_destroy
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      domain, name = @argv
      puts "Deleteing #{name} from #{domain}"
      @sdb.destroy domain, name
    end
    
  end
  
end; end
end; end