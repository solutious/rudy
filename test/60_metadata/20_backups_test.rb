module Rudy::Test
  class Case_60_MetaData
    
    def create_backup
      back = Rudy::MetaData::Backup.new
      [:region, :zone, :environment, :role, :position].each do |n|
        back.send("#{n}=", @@global.send(n))
      end
      
      back.path = "/rudy/disk"
      back.size = 10
      
      back
    end
    
    def format_timestamp(dat)
      mon, day, hour, min, sec = [dat.mon, dat.day, dat.hour, dat.min, dat.sec].collect { |v| v.to_s.rjust(2, "0") }
      [dat.year, mon, day, Rudy::RUDY_DELIM, hour, min, Rudy::RUDY_DELIM, sec].join
    end
    
    xcontext "#{name}_20 Backups" do
      
      should "(00) have global setup" do
        [:region, :zone, :environment, :role, :position].each do |n|
          assert @@global.respond_to?(n), "No global #{n}"
        end
      end
      
      should "(01) have domain" do
        #assert @@sdb.domains.create(Rudy::RUDY_DOMAIN), "Domain not created (#{Rudy::RUDY_DOMAIN})"
      end
      
      
      should "(10) create a backup object" do
        back = create_backup
        
        back_name = []
        [:region, :zone, :environment, :role, :position].each do |n|
          back_name << @@global.send(n)
        end
        p back_name
        back_time = format_timestamp(Time.now.utc)
        
        back_name.shift   # don't use region in backup name, but add the backup identifier and path
        back_name = ['back', back_name, 'rudy', 'disk', back_time].join(Rudy::RUDY_DELIM)
        assert_equal back_name, back.name

        assert back.valid?, "Bcakup not valid"
        
        back.save
      end
      
      should "(20) list metadata" do
        q = "select * from #{Rudy::RUDY_DOMAIN}"

        items = @@sdb.select(q)
        assert_equal Hash, items.class
        assert items.size > 0, "No backups"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(22) list backup metadata with select" do
        q = "select * from #{Rudy::RUDY_DOMAIN} where rtype = 'back'"
        items = @@sdb.select(q)
        assert_equal Hash, items.class
        assert items.size > 0, "No backups"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(23) list backup metadata with query" do
        q = "select * from #{Rudy::RUDY_DOMAIN} where rtype = 'back'"
        
        items = @@sdb.query_with_attributes(Rudy::RUDY_DOMAIN, "['rtype' = 'back']")
        assert_equal Hash, items.class
        assert items.size > 0, "No backups"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(30) get backup metadata" do
        back_tmp = create_backup
        back = Rudy::MetaData::Backup.get(back_tmp.name)
        assert_equal Rudy::MetaData::Backup, back.class
        assert_equal @@global.zone.to_s, back.zone.to_s
        
      end
      
      should "(40) destroy backup metadata" do
        q = "select * from #{Rudy::RUDY_DOMAIN} where rtype = 'back'"
        items = @@sdb.select(q)
        assert_equal Hash, items.class
        items.keys.each do |item|
          @@sdb.destroy(Rudy::RUDY_DOMAIN, item)
        end
      end
      
    end
    
    
    
     
  end
end