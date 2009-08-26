# Rudy Windows Machines
#
# This configuration is used to 
# test windows instance support.


defaults do
  color true
  environment :test
  role :windows
  zone :'eu-west-1b'
  bucket 'rudy-ami-eu'
end

machines do
  region :'us-east-1' do
    ami 'ami-de4daab7'               # Amazon Windows Server 2003 (US)
    size 'm1.small'
  end
  region :'eu-west-1' do
    ami 'ami-8696bef2'               # Rudy Windows 2009-08-24 (EU)
  end
  env :test do
    role :windows do
      os :windows
      user :Administrator
      disks do
        path "F:" do
          size 1
          device 'xvdf'
          fstype 'ntfs'
        end
        path "E:" do
          size 2
          device 'xvde'
        end
        path 'L:' do
          size 3
          device 'xvdl'
        end
      end
    end
  end
end


commands do
  allow :rm
end

routines do
  
  create_disks do
    disks do
      create "L:"
      #create "F:"
      #create "E:"
    end
    
  end
  
  shutdown do
    disks do
      destroy "L:"
      #destroy "F:"
      #destroy "E:"
    end
      
  end
  
  
  upload_config do
    remote :root do
      puts "Uploading rudy config"
      home = guess_user_home
      mkdir :p, "#{home}/.rudy", "#{home}/.ssh", ".ssh"
      disable_safe_mode
      file_upload '~/.rudy/config', "#{home}/.rudy/config"
      puts "Uploading keypair"
      file_upload '~/.ssh/id_rsa', '~/.ssh/key-eu-west-1b-test-windows', "#{home}/.ssh/"
      file_upload '~/.ssh/id_rsa', '~/.ssh/key-eu-west-1b-test-windows', ".ssh/"
    end
  end
  
end


__END__

* diskpart script example
  * http://social.technet.microsoft.com/Forums/en-US/winserversetup/thread/2cfbaae1-6e33-4197-bb71-63434a34eb3c
  * http://technet.microsoft.com/en-us/library/cc766465(WS.10).aspx
  
* format docs
  * http://www.computerhope.com/formathl.htm

* Securing Remote Desktop with copSSH
  * http://www.teamhackaday.com/2008/04/23/securing-windows-remote-desktop-with-copssh/
  
* Windows SSH
  * http://www.windowsnetworking.com/articles_tutorials/install-SSH-Server-Windows-Server-2008.html
