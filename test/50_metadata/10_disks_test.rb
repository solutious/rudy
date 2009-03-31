module Rudy::Test
  class Case_50_MetaData
    
    def create_disk
      disk = Rudy::MetaData::Disk.new
      [:region, :zone, :environment, :role, :position].each do |n|
        disk.send("#{n}=", @@global.send(n))
      end
      
      disk.path = "/rudy/disk"
      disk.size = 10
      disk.device = "/dev/sdh"
      disk
    end
    
    context "#{name}_10 Disks" do
      
      should "(00) have global setup" do
        [:region, :zone, :environment, :role, :position].each do |n|
          assert @@global.respond_to?(n), "No global #{n}"
        end
      end
      
      should "(01) have domain" do
        #assert @@sdb.domains.create(Rudy::RUDY_DOMAIN), "Domain not created (#{Rudy::RUDY_DOMAIN})"
      end
      
      
      should "(10) create a disk object" do
        disk = create_disk
        
        disk_name = []
        [:region, :zone, :environment, :role, :position].each do |n|
          disk_name << @@global.send(n)
        end
        
        disk_name.shift   # don't use region in disk name, but add the disk identifier and path
        disk_name = [Rudy.identifier(:disk), disk_name, 'rudy', 'disk'].join(Rudy::RUDY_DELIM)
        
        assert_equal disk_name, disk.name, "Unexpected disk name #{disk.name}"
        assert disk.valid?, "Disk not valid"
        
        disk.save
      end
      
      should "(20) list disks" do
        q = "select * from #{Rudy::RUDY_DOMAIN}"

        items = @@sdb.select(q)
        assert_equal Hash, items.class
        assert items.size > 0, "No disks"
        assert_equal @@global.zone.to_s, items.values.first['zone'].first.to_s
      end
      
      should "(30) get disk object" do
        disk_tmp = create_disk
        
        disk = Rudy::MetaData::Disk.get(disk_tmp.name)
        assert_equal Rudy::MetaData::Disk, disk.class
        assert_equal @@global.zone.to_s, disk.zone.to_s
      end
      
    end
    
    
    
     
  end
end