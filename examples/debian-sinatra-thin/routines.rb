# Rudy -- debian-sinatra-thin
#
# Notes:
# * Change :rudy to the name of your user remote deployment user
# 
# THIS EXAMPLE IS INCOMPLETE -- 2009-05-03
routines do
  
  test1 do
    disks do 
      create "/rudy/disk1"
    end
  end
  
  test2 do
    disks do 
      destroy "/rudy/disk1"
    end
  end
  sysupdate do
    before :root do                  
      apt_get "update"               
      apt_get "install", "build-essential", "git-core"
      apt_get "install", "sqlite3", "libsqlite3-dev"
      apt_get "install", "ruby1.8-dev", "rubygems"
      apt_get "install", "apache2-prefork-dev", "libapr1-dev"
      apt_get "install", "libfcgi-dev", "libfcgi-ruby1.8"
      gem_sources :a, "http://gems.github.com"
    end
  end
  
  installdeps do
    before :root do
      gem_install "test-spec", "rspec", "camping", "fcgi", "memcache-client"
      gem_install "mongrel"
      gem_install 'ruby-openid', :v, "2.0.4" # thin requires 2.0.x
      gem_install "rack", :v, "0.9.1"
      gem_install "macournoyer-thin"         # need 1.1.0 which works with rack 0.9.1
      gem_install "sinatra"
    end
  end
  
  environment :dev, :stage do
    
    startup do      
      adduser :rudy
      authorize :rudy  
      disks do
        create "/rudy/disk1"
      end
    end
    
    release do
      git :rudy do
        privatekey '/Users/rudy/.ssh/git-rudy_rsa'
        remote :origin
        path "/rudy/disk1/app/rudytes"
      end
      after :rudy do
        thin :c, "/rudy/disk1/app/rudytes/", "start"
      end
    end
    
    # This routine will be executed when you run "rudy shutdown"
    shutdown do
      disks do
        # Rudy unmounts the EBS volume and deletes it. Careful! 
        #destroy "/rudy/disk1"
      end
    end
  end
  
end

__END__


rerelease do
  before :rudy do
    thin :c, "/rudy/disk1/app/rudytes/", "stop"
  end
  git :rudy do
    remote :origin
    path "/rudy/disk1/app/rudytes"
  end
  after :rudy do
    thin :c, "/rudy/disk1/app/rudytes/", "start"
  end
end

restart do
  after :rudy do
    thin :c, "/rudy/disk1/app/rudytes/", "restart"
  end
end

start do
  after :rudy do
    thin :c, "/rudy/disk1/app/rudytes/", "start"
  end
end
stop do
  after :rudy do
    thin :c, "/rudy/disk1/app/rudytes/", "stop"
  end
end



