module Rudy::Test
  class Case_30_MetaData

    
    context "#{name}_10 Disks" do
      
      setup do
        @sdb = Rudy::AWS::SDB.new(@@global.accesskey, @@global.secretkey)
        #@ami = @@config.machines.find(@@zone.to_sym, :ami)
      end
      
      
      should "(00) have global setup" do
        [:region, :zone, :environment, :role, :position].each do |n|
          assert @@global.respond_to?(n), "No global #{n}"
        end
      end
      
      should "(01) have domain" do
        assert @sdb.create_domain(Rudy::DOMAIN), "Domain not created (#{Rudy::DOMAIN})"
      end
      
      
      should "(10) create a disk object" do
        disk = Rudy::Disk.new('/rudy/disk', 1, '/dev/sdh')
        
        disk_name_elements = []
        [:zone, :environment, :role, :position].each do |n|
          disk_name_elements << @@global.send(n)
        end
        
        # disk-us-east-1b-stage-app-01-rudy-disk
        disk_name = ['disk', disk_name_elements, 'rudy', 'disk'].join(Rudy::DELIM)
        
        assert_equal disk_name, disk.name, "Unexpected disk name #{disk.name}"
        assert disk.valid?, "Disk not valid"
        
        puts disk.name
        #disk.save
      end
      
      should "(11) save a disk object" do
        disk = Rudy::Disk.new('/rudy/disk', 1, '/dev/sdh')
        assert disk.is_a?(Rudy::Disk), "Not a Rudy::Disk (#{disk})"
        assert disk.save, "Did not save #{disk.name}"
      end
      
      should "(20) list metadata with select" do
        q = "select * from #{Rudy::DOMAIN}"

        items = @sdb.select(q)
        assert_equal Hash, items.class
        assert items.size > 0, "No disks"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(22) list disk metadata with select" do
        q = "select * from #{Rudy::DOMAIN} where rtype = 'disk'"
        items = @sdb.select(q)
        assert_equal Hash, items.class
        assert items.size > 0, "No disks"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(23) list disk metadata with query" do
        q = "select * from #{Rudy::DOMAIN} where rtype = 'disk'"
        
        items = @sdb.query_with_attributes(Rudy::DOMAIN, "['rtype' = 'disk']")
        assert_equal Hash, items.class
        assert items.size > 0, "No disks"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(30) get disk from Rudy::Disks, modify, and save" do
        disk_tmp = Rudy::Disk.new('/rudy/disk', 1, '/dev/sdh')
        disk_orig = Rudy::Disks.get(disk_tmp.name)
        assert_equal Rudy::Disk, disk_orig.class, "Not a Rudy::Disk #{disk_orig}"
        assert_equal @@global.zone.to_s, disk_orig.zone.to_s, "Unexpected zone #{disk_orig.zone}"
        
        disk_orig.size = 2
        assert disk_orig.save, "Did not save #{disk_orig.name}"
        disk_new = Rudy::Disks.get(disk_orig.name)
        assert_equal disk_orig.size, disk_new.size, "Different size #{disk_new.size}"
        assert disk_new.destroy, "Did not destroy #{disk_new.name}"
      end
      
      
      should "(90) destroy all disk metadata" do
        q = "select * from #{Rudy::DOMAIN} where rtype = 'disk'"
        items = @sdb.select(q)
        assert_equal Hash, items.class
        items.keys.each do |item|
          @sdb.destroy(Rudy::DOMAIN, item)
        end
      end
      
      should "(99) destroy domain" do
        assert @sdb.destroy_domain(Rudy::DOMAIN), "Domain not destroyed (#{Rudy::DOMAIN})"
      end
      
    end
    
    
    
     
  end
end