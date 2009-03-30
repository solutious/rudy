


module Rudy::AWS
  class SimpleDB
    class Domains 
      include Rudy::AWS::ObjectBase
      
      def create(name)
        @aws.create_domain(name)
        true
      end
      
      def destroy(name)
        @aws.delete_domain(name)  # Always returns nil, wtf?
        true
      end
    
      def list
        domains = (@aws.list_domains || [[]])  # Nested array, again wtf?
        domains.first.flatten
      end
    end
    
    def destroy(domain, item)
      @aws.delete_attributes(domain, item)
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
    
    def get_attributes(domain, item)
      @aws.get_attributes(domain, item)
    end
  end
end
