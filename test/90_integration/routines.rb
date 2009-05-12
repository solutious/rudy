

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
  
  startup do
  end
  
  env :stage do
    role :windows do
      getpassword do
        
      end
    end
  end
  
end