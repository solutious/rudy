module Rudy::Test
  class Case_50_MetaData
    
    context "#{name}_10 Disks" do
      
      should "(00) have global setup" do
        [:region, :zone, :environment, :role, :position].each do |n|
          assert @@global.respond_to?(n), "No global #{n}"
        end
      end
      
      should "(10) create a disk object" do
        
        disk_name = []
        
        disk = Rudy::MetaData::Disk.new
        [:region, :zone, :environment, :role, :position].each do |n|
          disk.send("#{n}=", @@global.send(n))
          disk_name << @@global.send(n)
        end
        
        disk.path = "/rudy/disk"
        disk.size = 10
        disk.device = "/dev/sdh"
        
        disk_name.shift   # don't use region in disk name, but add the disk identifier and path
        disk_name = [Rudy.identifier(:disk), disk_name, 'rudy', 'disk'].join(Rudy::RUDY_DELIM)
        
        assert_equal disk_name, disk.name, "Unexpected disk name #{disk.name}"
        assert disk.valid?, "Disk not valid"
      end
      
    end
    
     
  end
end