module Rudy::Test
  class TC_20_SimpleDB
    
    
    def get_domain

    end
    
    context "#{name} Domains" do
      
      setup do
        @domain_list = @@sdb.domains.list || []
        @domain = @domain_list.first
      end
      
      should "(10) create domain" do
        dname = 'test_' << Rudy::Utils.strand
        assert @@sdb.domains.create(dname), "Domain not created (#{dname})"
      end
      
      should "(20) list domains" do
        domain_list = @@sdb.domains.list
        assert domain_list.is_a?(Array), "Not an Array"
        assert !domain_list.empty?, "No Domains"
      end
      
      should "(30) store objects" do
        
        assert @domain_list.is_a?(Array), "Not an Array"
        assert !@domain_list.empty?, "No Domains"
        
        produce = lambda {
          {
            'orange' => rand(100) * 10,
            'celery' => rand(100) * 100,
            'grapes' => :green
          }
        }
        
        @@sdb.store(@domain, 'produce1', produce.call, :replace)
        @@sdb.store(@domain, 'produce2', produce.call, :replace)
        
      end
      
      should "(40) query objects" do
        
        assert @domain_list.is_a?(Array), "Not an Array"
        assert !@domain_list.empty?, "No Domains"
        
        items = @@sdb.query(@domain, "[ 'grapes' = 'green' ]")
        assert items.is_a?(Array), "Not an Array"
        assert_equal 2, items.size, "More than 2 objects"
      end
      
      should "(41) query objects with attribtues" do
        
        assert @domain_list.is_a?(Array), "Not an Array"
        assert !@domain_list.empty?, "No Domains"
        
        items = @@sdb.query_with_attributes(@domain, "[ 'grapes' = 'green' ]")
        assert items.is_a?(Hash), "Not a Hash"
        assert_equal 2, items.keys.size, "More than 2 objects"
        assert items['produce1']['celery'].first.to_i > 1000, "Celery less than 1000"
      end
      
      should "(50) select objects" do
        assert @domain_list.is_a?(Array), "Not an Array"
        assert !@domain_list.empty?, "No Domains"
        q = "select * from #{@domain}"

        items = @@sdb.select(q)
        assert items.is_a?(Hash), "Not a Hash"
        assert_equal 2, items.keys.size, "More than 2 objects"
        
        # {"produce1"=>{"celery"=>["5200"], "grapes"=>["green"], "orange"=>["550"]}}
        assert items['produce1']['celery'].first.to_i > 1000, "Celery less than 1000"
      end
      
      
      should "(99) destroy domains" do
        
        assert @domain_list.is_a?(Array), "Not an Array"
        assert !@domain_list.empty?, "No Domains"
        
        @domain_list.each do |domain|
          assert @@sdb.domains.destroy(domain), "Not destroyed (#{domain})"
        end
        
        domain_list = @@sdb.domains.list
        assert domain_list.empty?, "Not empty"
      end
      
    end
    
  end
end