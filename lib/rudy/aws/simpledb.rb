


module Rudy::AWS
  class SimpleDB
    class Domains 
      include Rudy::AWS::ObjectBase
      
      def create(name)
        @aws.create_domain(name)
      end
      
      def destroy(name)
        @aws.delete_domain(name)
      end
    
      def list
        @aws.list_domains
      end
    end
    
    def destroy(domain, item, attributes={})
      @aws.delete_attributes(domain, item, attributes)
    end
    
    def store(domain, item, attributes={}, replace=false)
      replace &&= true  # Accept any value as true
      @aws.put_attributes(domain, item, attributes, replace)
    end
    
    def query(domain, query=nil, max=nil)
      @aws.query(domain, query, max)
    end
    
    def query_with_attributes(domain, query, max=nil)
      # FIX OUTPUT
      items = @aws.query_with_attributes(domain, query, max)
      return nil if !items || items.empty? || items == [[], ""]  # NOTE: wtf, aws-sdb?
      clean_items = {}
      # [[{"device"=>["/dev/sdh"], "Name"=>"disk-us-east-1b-stella-app-01-stella", "zone"=>["us-east-1b"], 
      # "size"=>["1"], "region"=>["us-east-1"], "role"=>["app"], "rtype"=>["disk"], "awsid"=>[""], 
      # "environment"=>["stella"], "position"=>["01"], "path"=>["/stella"]}], ""]
      items.flatten.each do |disk|
        next unless disk.is_a?(Hash)
        name = disk.delete("Name")
        clean_items[name] = Rudy::MetaData::Disk.from_hash(disk)
      end
      clean_items
    end
    
    def select(query)
      list = @aws.select(query) || []
      list[0]
    end
    
    def get_attributes(domain, item, attribute=nil)
      @aws.get_attributes(domain, item, attribute)
    end
  end
end
