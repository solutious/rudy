rudy_lib_path = File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))
library :rudy, rudy_lib_path

group "SimpleDB"

test_domain = 'test_' << Rudy::Utils.strand
produce = {
  'orange' => (rand(100) * 10).to_s,
  'celery' => (rand(100) * 100).to_s,
  'grapes' => 'green'
}


tryouts "Objects" do
  setup do
    Rudy::Huxtable.update_config
    global = Rudy::Huxtable.global
    akey, skey, region = global.accesskey, global.secretkey, global.region
    @@sdb = Rudy::AWS::SDB.new(akey, skey, region)
  end
  
  drill "create test domain (#{test_domain})" do
    @@sdb.create_domain test_domain
  end
  
  drill "put object" do
    stash :product1, produce
    @@sdb.put(test_domain, 'produce1', produce, :replace)
  end
  
  drill "get object by name" do
    from_sdb = @@sdb.get(test_domain, 'produce1')
    stash :product1, from_sdb
    [from_sdb.keys.sort, from_sdb.values.collect { |v| v.first }.sort ]
  end
  
  drill "select object" do
    stash[:query] = "select * from #{test_domain}"
    stash[:items] = @@sdb.select stash[:query]
    stash[:items].is_a?(Hash) && stash[:items].keys.size > 0
  end
  
  drill "destroy objects by name" do
    items = @@sdb.select "select * from #{test_domain}"
    items.keys.each { |name| @@sdb.destroy test_domain, name }
    @@sdb.select("select * from #{test_domain}").nil?
  end
  
  drill "destroy test domain (#{test_domain})" do
    @@sdb.destroy_domain test_domain
  end
  
end
dreams "Objects" do
  dream "create simpledb connection", Rudy::AWS::SDB, :class
  dream "create test domain (#{test_domain})", true
  dream "put object", true
  dream "get object by name", [produce.keys.sort, produce.values.sort]
  dream "select object", true
  dream "destroy objects by name", true
  dream "destroy test domain (#{test_domain})", true
end