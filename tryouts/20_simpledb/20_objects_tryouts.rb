
library :rudy, 'lib'

group "SimpleDB"

tryouts "Objects" do

  set :test_domain, 'test_' << Rudy::Utils.strand
  set :produce, Hash[
    'orange' => (rand(100) * 10).to_s,
    'celery' => (rand(100) * 100).to_s,
    'grapes' => 'green'
  ]


  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  drill "create test domain (#{test_domain})", true do
    @sdb.create_domain test_domain
  end
  
  drill "put object", true do
    stash :product1, produce
    @sdb.put(test_domain, 'produce1', produce, :replace)
  end
  
  drill "get object by name", [produce.keys.sort, produce.values.sort] do
    from_sdb = @sdb.get(test_domain, 'produce1')
    stash :product1, from_sdb
    [from_sdb.keys.sort, from_sdb.values.collect { |v| v.first }.sort ]
  end
  
  drill "select objects", :gt, 0 do
    stash[:query] = "select * from #{test_domain}"
    stash[:items] = @sdb.select stash[:query]
    stash[:items].is_a?(Hash) && stash[:items].keys.size
  end
  
  dream true
  drill "destroy objects by name" do
    items = @sdb.select "select * from #{test_domain}"
    items.keys.each { |name| @sdb.destroy test_domain, name }
    @sdb.select("select * from #{test_domain}").nil?
  end
  
  drill "destroy test domain (#{test_domain})", true do
    @sdb.destroy_domain test_domain
  end
  
end

