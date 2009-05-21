# THIS EXAMPLE IS INCOMPLETE -- 2009-05-03

# Rudy -- debian-sinatra-thin
#
# Notes:
# * Change :rudy to the name of your user remote deployment user
# 
sinatra_home = "/rudy/disk1/sinatra"
routines do
  
  sysupdate do
    script :root do                  
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
    script :root do
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
    shutdown do
      disks do
        destroy "/rudy/disk1"   
      end
    end
    
    restart do
      after :rudy do
        thin :c, sinatra_home, "restart"
      end
    end
    start do
      after :rudy do
        thin :c, sinatra_home, "start"
      end
    end
    stop do
      after :rudy do
        thin :c, sinatra_home, "stop"
      end
    end

    
  end
  
end




