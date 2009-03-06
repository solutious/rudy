


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
      @aws.put_attributes(domain, item, attributes, replace)
    end
    
    def query(domain, query=nil, max=nil)
      @aws.query(domain, query, max)
    end
    
    def query_with_attributes(domain, query, max=nil)
      items = {}
      query(domain, query)[:items].each do |item|
        items[item] = get_attributes(domain, item)[:attributes]
      end
      items
    end
    
    def select(query)
      list = @aws2.select(query) || []
      list[0]
    end
    
    def get_attributes(domain, item, attribute=nil)
      @aws.get_attributes(domain, item, attribute)
    end
  end
end
