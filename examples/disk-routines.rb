

routines do
  
  create do
    disks do
      create "/rudy/disk1"
    end
  end
  
  detach do
    disks do
      detach "/rudy/disk1"
    end
  end
  
  attach do
    disks do
      attach "/rudy/disk1"
    end
  end
  
  mount do
    disks do
      mount "/rudy/disk1"
    end
  end
  
  
  umount do
    disks do
      umount "/rudy/disk1"
    end
  end
  
  
  format do
    disks do
      format "/rudy/disk1"
    end
  end
  
    
  destroy do
    disks do
      destroy "/rudy/disk1"
    end
  end

  
  archive do
    disks do
      archive "/rudy/disk1"
    end
  end
  
  restore do
    disks do 
      restore "/rudy/disk1" do
        device "/dev/sdr"
      end
    end
  end
end