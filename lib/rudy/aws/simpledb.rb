


module Rudy; module AWS
  class SimpleDB
    include Rudy::Huxtable
    
    attr_reader :domains
    attr_reader :aws
    
    def initialize(access_key=@@global.accesskey, secret_key=@@global.secretkey)
      @aws = AwsSdb::Service.new(:access_key_id => access_key, :secret_access_key => secret_key, :logger => Logger.new(@@logger))
    end
    
    
    def create_domain(name)
      @aws.create_domain(name)
      true
    end
    
    def destroy_domain(name)
      @aws.delete_domain(name) # Always returns nil, wtf?
      true
    end
  
    def list_domains
      domains = (@aws.list_domains || [[]]) # Nested array, again wtf?
      domains.first.flatten
    end
    
    # Takes a zipped Array or Hash of criteria.
    # Returns a string suitable for a SimpleDB Query
    def SimpleDB.generate_query(*args)
      q = args.first.is_a?(Hash)? args.first : Hash[*args.flatten]
      query = []
      q.each do |n,v| 
        query << "['#{Rudy::AWS.escape n}'='#{Rudy::AWS.escape v}']"
      end
      query.join(" intersection ")
    end
    
    # Takes a zipped Array or Hash of criteria.
    # Returns a string suitable for a SimpleDB Select
    def SimpleDB.generate_select(*args)
      fields, domain, args = *args
      q = args.is_a?(Hash) ? args : Hash[*args.flatten]
      query = []
      q.each do |n,v| 
        query << "#{Rudy::AWS.escape n}='#{Rudy::AWS.escape v}'"
      end
      "select * from #{domain} where " << query.join(' and ')
    end
    
    def destroy(domain, item)
      @aws.delete_attributes(domain, item)
      true
    end
    
    def store(domain, item, attributes={}, replace=false)
      replace &&= true  # Accept any value as true
      @aws.put_attributes(domain, item, attributes, replace)
    end
    
    def query(domain, query=nil, max=nil)
      items = @aws.query(domain, query, max)
      return nil if !items || items.empty? || items == [[], ""]  # NOTE: wtf, aws-sdb?
      # [["produce", "produce1", "produce2"], ""]
      clean_items = items.first
      clean_items
    end
    
    def query_with_attributes(domain, query, max=nil)
      items = @aws.query_with_attributes(domain, query, max)
      return nil if !items || items.empty? || items == [[], ""]  # NOTE: wtf, aws-sdb?
      clean_items = {}
      # aws-sdb returns the following (another nested array -- wtf X 9):
      # [[{"device"=>["/dev/sdh"], "Name"=>"disk-us-east-1b-stella-app-01-stella", "zone"=>["us-east-1b"], 
      # "size"=>["1"], "region"=>["us-east-1"], "role"=>["app"], "rtype"=>["disk"], "awsid"=>[""], 
      # "environment"=>["stella"], "position"=>["01"], "path"=>["/stella"]}], ""]
      items.first.each do |item|
        clean_items[item.delete('Name')] = item
      end
      clean_items
    end
    
    def select(query)
      items = @aws.select(query) || []
      return nil if !items || items.empty? || items == [[], ""]  # NOTE: wtf, aws-sdb?
      clean_items = {}
      items.first.each do |item|
        clean_items[item.delete('Name')] = item
      end
      clean_items
    end
    
    def get(domain, item)
      @aws.get_attributes(domain, item)
    end
  end
end; end
