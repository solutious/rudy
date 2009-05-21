
routines do
  
  sysupdate do
    script :root do                  
      apt_get "update"               
      apt_get "install", "build-essential", "git-core"
      apt_get "install", "sqlite3", "libsqlite3-dev"
      apt_get "install", "ruby1.8-dev", "rubygems"
      apt_get "install", "nginx"
      apt_get "install", "apache2-mpm-prefork", "apache2-prefork-dev", "libapr1-dev"
      apt_get "install", "libfcgi-dev", "libfcgi-ruby1.8"
      gem_sources :a, "http://gems.github.com"
    end
  end
  
  installdeps do
    script :root do
      gem_install "test-spec", "rspec", "camping", "fcgi", "memcache-client"
      gem_install "rake", "passenger"
      passenger_install_apache2
      passenger_install_nginx
      gem_install "rack", :v, "0.9.1"   # 0.9.1 required by sinatra
      gem_install "sinatra"
    end
  end
  
  
  
end