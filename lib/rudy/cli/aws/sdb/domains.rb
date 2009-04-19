

module Rudy; module CLI; 
module AWS; module SDB;
  
  class Domains < Rudy::CLI::CommandBase
    
    
    def domains
      sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      domains = sdb.list_domains
      puts domains
      puts "No domains" if domains.nil? || domains.empty?
    end
    
    def domains_create_valid?
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise "No name specified" unless @argv.name
      true
    end
    def domains_create
      @sdb.create_domain @argv.name
      execute_check(:low)
      domains
    end
    
    def domains_destroy_valid?
      @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey, @@global.region)
      raise "No name specified" unless @argv.name
      true
    end
    def domains_destroy
      execute_check(:medium)
      @sdb.destroy_domain @argv.name
      domains
    end
    
  end
  
end; end
end; end